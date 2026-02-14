import Foundation
import Virtualization
import SwiftUI

@MainActor
class VMManager: NSObject, ObservableObject, VZVirtualMachineDelegate {
    @Published var logs: [String] = []
    @Published var downloadProgress: Double = 0
    @Published var installProgress: Double = 0
    @Published var isDownloading = false
    @Published var isInstalling = false
    @Published var isRunning = false
    @Published var hasIPSW = false
    @Published var isInstalled = false
    
    let bundlePath: String
    @Published private(set) var virtualMachine: VZVirtualMachine?
    private var installObservation: NSKeyValueObservation?
    
    var ipswPath: String { "\(bundlePath)/RestoreImage.ipsw" }
    var diskPath: String { "\(bundlePath)/Disk.img" }
    var auxPath: String { "\(bundlePath)/AuxiliaryStorage" }
    var machineIdPath: String { "\(bundlePath)/MachineIdentifier" }
    var hardwareModelPath: String { "\(bundlePath)/HardwareModel" }
    
    var ipswStatus: String {
        hasIPSW ? "✅ 已下載" : "❌ 未下載"
    }
    
    var vmStateText: String {
        if isRunning { return "🟢 運行中" }
        if isInstalled { return "🟡 已安裝（已停止）" }
        if hasIPSW { return "⚪ 待安裝" }
        return "⚫ 未設定"
    }
    
    var vmStateColor: Color {
        if isRunning { return .green }
        if isInstalled { return .yellow }
        return .secondary
    }
    
    override init() {
        self.bundlePath = NSString(string: "~/MacVM.bundle").expandingTildeInPath
        super.init()
        checkStatus()
    }
    
    func log(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        logs.append("[\(timestamp)] \(message)")
    }
    
    func checkStatus() {
        let fm = FileManager.default
        hasIPSW = fm.fileExists(atPath: ipswPath)
        
        // 檢查磁碟大小來判斷是否真的安裝完成（至少 20GB 才算安裝成功）
        if let attrs = try? fm.attributesOfItem(atPath: diskPath),
           let size = attrs[.size] as? Int64 {
            let sizeGB = size / 1024 / 1024 / 1024
            isInstalled = sizeGB >= 20 && fm.fileExists(atPath: auxPath)
        } else {
            isInstalled = false
        }
        
        // Create bundle if needed
        if !fm.fileExists(atPath: bundlePath) {
            try? fm.createDirectory(atPath: bundlePath, withIntermediateDirectories: true)
            log("Created VM bundle at \(bundlePath)")
        }
        
        log("狀態檢查完成: IPSW=\(hasIPSW), Installed=\(isInstalled)")
    }
    
    func downloadIPSW() async {
        guard !hasIPSW else { return }
        
        isDownloading = true
        log("🔍 正在獲取最新的 macOS 恢復映像...")
        
        do {
            let image = try await VZMacOSRestoreImage.latestSupported
            log("📥 下載 macOS \(image.operatingSystemVersion.majorVersion).\(image.operatingSystemVersion.minorVersion) (Build \(image.buildVersion))")
            
            let (tempURL, _) = try await URLSession.shared.download(from: image.url, delegate: DownloadDelegate(manager: self))
            try FileManager.default.moveItem(at: tempURL, to: URL(fileURLWithPath: ipswPath))
            
            hasIPSW = true
            log("✅ 下載完成")
        } catch {
            log("❌ 下載失敗: \(error.localizedDescription)")
        }
        
        isDownloading = false
        downloadProgress = 0
    }
    
    func installMacOS() async {
        guard hasIPSW && !isInstalled else { return }
        
        isInstalling = true
        log("📦 開始安裝 macOS...")
        
        do {
            let ipswURL = URL(fileURLWithPath: ipswPath)
            let restoreImage = try await VZMacOSRestoreImage.image(from: ipswURL)
            
            guard let requirements = restoreImage.mostFeaturefulSupportedConfiguration else {
                throw NSError(domain: "VMManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "不支援的配置"])
            }
            
            log("📋 硬體需求: CPU \(requirements.minimumSupportedCPUCount), RAM \(requirements.minimumSupportedMemorySize / 1024 / 1024 / 1024)GB")
            
            // Create configuration
            let config = try await createConfiguration(requirements: requirements)
            
            // Create VM and install
            let vm = VZVirtualMachine(configuration: config)
            virtualMachine = vm
            
            let installer = VZMacOSInstaller(virtualMachine: vm, restoringFromImageAt: ipswURL)
            
            installObservation = installer.progress.observe(\.fractionCompleted) { progress, _ in
                let fraction = progress.fractionCompleted
                Task { @MainActor [weak self] in
                    self?.installProgress = fraction
                }
            }
            
            try await installer.install()
            installObservation?.invalidate()
            
            isInstalled = true
            log("✅ macOS 安裝完成！")
        } catch {
            log("❌ 安裝失敗: \(error.localizedDescription)")
        }
        
        isInstalling = false
        installProgress = 0
    }
    
    func createConfiguration(requirements: VZMacOSConfigurationRequirements) async throws -> VZVirtualMachineConfiguration {
        let config = VZVirtualMachineConfiguration()
        
        // Platform
        let platform = VZMacPlatformConfiguration()
        
        // Auxiliary storage
        let auxURL = URL(fileURLWithPath: auxPath)
        if FileManager.default.fileExists(atPath: auxPath) {
            platform.auxiliaryStorage = VZMacAuxiliaryStorage(contentsOf: auxURL)
        } else {
            platform.auxiliaryStorage = try VZMacAuxiliaryStorage(creatingStorageAt: auxURL, hardwareModel: requirements.hardwareModel, options: [])
        }
        
        // Machine identifier
        let machineIdURL = URL(fileURLWithPath: machineIdPath)
        if FileManager.default.fileExists(atPath: machineIdPath),
           let data = try? Data(contentsOf: machineIdURL),
           let id = VZMacMachineIdentifier(dataRepresentation: data) {
            platform.machineIdentifier = id
        } else {
            let id = VZMacMachineIdentifier()
            try id.dataRepresentation.write(to: machineIdURL)
            platform.machineIdentifier = id
        }
        
        platform.hardwareModel = requirements.hardwareModel
        config.platform = platform
        
        // CPU & Memory
        config.cpuCount = max(requirements.minimumSupportedCPUCount, 4)
        config.memorySize = max(requirements.minimumSupportedMemorySize, 8 * 1024 * 1024 * 1024)
        
        // Boot Loader
        config.bootLoader = VZMacOSBootLoader()
        
        // Graphics
        let graphics = VZMacGraphicsDeviceConfiguration()
        graphics.displays = [VZMacGraphicsDisplayConfiguration(widthInPixels: 1920, heightInPixels: 1200, pixelsPerInch: 144)]
        config.graphicsDevices = [graphics]
        
        // Storage
        let diskURL = URL(fileURLWithPath: diskPath)
        if !FileManager.default.fileExists(atPath: diskPath) {
            try createDiskImage(at: diskURL, sizeGB: 80)
        }
        let diskAttachment = try VZDiskImageStorageDeviceAttachment(url: diskURL, readOnly: false)
        config.storageDevices = [VZVirtioBlockDeviceConfiguration(attachment: diskAttachment)]
        
        // Network
        let network = VZVirtioNetworkDeviceConfiguration()
        network.attachment = VZNATNetworkDeviceAttachment()
        config.networkDevices = [network]
        
        // Keyboard & Mouse
        config.keyboards = [VZUSBKeyboardConfiguration()]
        config.pointingDevices = [VZUSBScreenCoordinatePointingDeviceConfiguration()]
        
        // Audio
        let audio = VZVirtioSoundDeviceConfiguration()
        let input = VZVirtioSoundDeviceInputStreamConfiguration()
        input.source = VZHostAudioInputStreamSource()
        let output = VZVirtioSoundDeviceOutputStreamConfiguration()
        output.sink = VZHostAudioOutputStreamSink()
        audio.streams = [input, output]
        config.audioDevices = [audio]
        
        try config.validate()
        log("✅ VM 配置驗證成功")
        
        return config
    }
    
    func createDiskImage(at url: URL, sizeGB: Int) throws {
        let size = sizeGB * 1024 * 1024 * 1024
        FileManager.default.createFile(atPath: url.path, contents: nil)
        let handle = try FileHandle(forWritingTo: url)
        try handle.truncate(atOffset: UInt64(size))
        try handle.close()
        log("💾 創建 \(sizeGB)GB 磁碟映像")
    }
    
    func startVM() async {
        guard isInstalled && !isRunning else { return }
        
        log("🖥️ 正在啟動 VM...")
        
        do {
            let ipswURL = URL(fileURLWithPath: ipswPath)
            let restoreImage = try await VZMacOSRestoreImage.image(from: ipswURL)
            
            guard let requirements = restoreImage.mostFeaturefulSupportedConfiguration else {
                throw NSError(domain: "VMManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "不支援的配置"])
            }
            
            let config = try await createConfiguration(requirements: requirements)
            let vm = VZVirtualMachine(configuration: config)
            vm.delegate = self
            virtualMachine = vm
            
            try await vm.start()
            isRunning = true
            log("✅ VM 啟動成功")
        } catch {
            log("❌ 啟動失敗: \(error.localizedDescription)")
        }
    }
    
    func stopVM() {
        guard isRunning, let vm = virtualMachine else { return }
        
        log("🛑 正在停止 VM...")
        
        Task {
            do {
                try await vm.stop()
                isRunning = false
                log("✅ VM 已停止")
            } catch {
                log("❌ 停止失敗: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - VZVirtualMachineDelegate
    
    nonisolated func virtualMachine(_ virtualMachine: VZVirtualMachine, didStopWithError error: Error) {
        Task { @MainActor in
            log("❌ VM 錯誤停止: \(error.localizedDescription)")
            isRunning = false
        }
    }
    
    nonisolated func guestDidStop(_ virtualMachine: VZVirtualMachine) {
        Task { @MainActor in
            log("🛑 Guest OS 已停止")
            isRunning = false
        }
    }
}

// MARK: - Download Delegate

class DownloadDelegate: NSObject, URLSessionDownloadDelegate {
    weak var manager: VMManager?
    
    init(manager: VMManager) {
        self.manager = manager
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        Task { @MainActor in
            manager?.downloadProgress = progress
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // Handled in main download function
    }
}
