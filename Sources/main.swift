import Foundation
import Virtualization

// MARK: - macOS VM Manager
class MacVMManager: NSObject, VZVirtualMachineDelegate {
    
    private var virtualMachine: VZVirtualMachine?
    private let vmBundlePath: String
    
    init(bundlePath: String = "~/MacVM.bundle") {
        self.vmBundlePath = NSString(string: bundlePath).expandingTildeInPath
        super.init()
    }
    
    // MARK: - Create VM Bundle Directory
    func createVMBundle() throws {
        let bundleURL = URL(fileURLWithPath: vmBundlePath)
        
        if !FileManager.default.fileExists(atPath: vmBundlePath) {
            try FileManager.default.createDirectory(at: bundleURL, withIntermediateDirectories: true)
            printFlush("✅ Created VM bundle at: \(vmBundlePath)")
        }
    }
    
    // MARK: - Download macOS Restore Image
    func downloadRestoreImage() async throws -> URL {
        let restoreImagePath = "\(vmBundlePath)/RestoreImage.ipsw"
        let restoreImageURL = URL(fileURLWithPath: restoreImagePath)
        
        if FileManager.default.fileExists(atPath: restoreImagePath) {
            printFlush("✅ Restore image already exists")
            return restoreImageURL
        }
        
        printFlush("🔍 Fetching latest macOS restore image...")
        let image = try await VZMacOSRestoreImage.latestSupported
        let downloadURL = image.url
        
        printFlush("📥 Downloading macOS \(image.operatingSystemVersion.majorVersion).\(image.operatingSystemVersion.minorVersion)...")
        printFlush("   Build: \(image.buildVersion)")
        printFlush("   URL: \(downloadURL)")
        printFlush("   This may take a while...")
        
        let (tempURL, _) = try await URLSession.shared.download(from: downloadURL)
        try FileManager.default.moveItem(at: tempURL, to: restoreImageURL)
        
        printFlush("✅ Download complete!")
        return restoreImageURL
    }
    
    // MARK: - Create VM Configuration
    func createConfiguration(restoreImageURL: URL) async throws -> VZVirtualMachineConfiguration {
        let restoreImage = try await VZMacOSRestoreImage.image(from: restoreImageURL)
        
        guard let requirements = restoreImage.mostFeaturefulSupportedConfiguration else {
            throw VMError.unsupportedConfiguration
        }
        
        printFlush("📋 Hardware requirements:")
        printFlush("   Min CPU: \(requirements.minimumSupportedCPUCount)")
        printFlush("   Min RAM: \(requirements.minimumSupportedMemorySize / 1024 / 1024 / 1024) GB")
        
        let config = VZVirtualMachineConfiguration()
        
        // Platform
        let platform = VZMacPlatformConfiguration()
        let auxStorage = try createAuxiliaryStorage(requirements: requirements)
        platform.auxiliaryStorage = auxStorage
        platform.hardwareModel = requirements.hardwareModel
        platform.machineIdentifier = VZMacMachineIdentifier()
        config.platform = platform
        
        // CPU & Memory
        config.cpuCount = max(requirements.minimumSupportedCPUCount, 4)
        config.memorySize = max(requirements.minimumSupportedMemorySize, 8 * 1024 * 1024 * 1024) // 8GB
        
        // Boot Loader
        config.bootLoader = VZMacOSBootLoader()
        
        // Graphics
        let graphics = VZMacGraphicsDeviceConfiguration()
        graphics.displays = [
            VZMacGraphicsDisplayConfiguration(widthInPixels: 1920, heightInPixels: 1200, pixelsPerInch: 144)
        ]
        config.graphicsDevices = [graphics]
        
        // Storage
        let diskURL = URL(fileURLWithPath: "\(vmBundlePath)/Disk.img")
        if !FileManager.default.fileExists(atPath: diskURL.path) {
            try createDiskImage(url: diskURL, sizeGB: 64)
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
        let audioInput = VZVirtioSoundDeviceInputStreamConfiguration()
        audioInput.source = VZHostAudioInputStreamSource()
        let audioOutput = VZVirtioSoundDeviceOutputStreamConfiguration()
        audioOutput.sink = VZHostAudioOutputStreamSink()
        audio.streams = [audioInput, audioOutput]
        config.audioDevices = [audio]
        
        // Validate
        try config.validate()
        printFlush("✅ Configuration validated")
        
        return config
    }
    
    // MARK: - Create Auxiliary Storage
    private func createAuxiliaryStorage(requirements: VZMacOSConfigurationRequirements) throws -> VZMacAuxiliaryStorage {
        let auxURL = URL(fileURLWithPath: "\(vmBundlePath)/AuxiliaryStorage")
        
        if FileManager.default.fileExists(atPath: auxURL.path) {
            return VZMacAuxiliaryStorage(contentsOf: auxURL)
        }
        
        return try VZMacAuxiliaryStorage(
            creatingStorageAt: auxURL,
            hardwareModel: requirements.hardwareModel,
            options: []
        )
    }
    
    // MARK: - Create Disk Image
    private func createDiskImage(url: URL, sizeGB: Int) throws {
        let size = sizeGB * 1024 * 1024 * 1024
        
        FileManager.default.createFile(atPath: url.path, contents: nil)
        let handle = try FileHandle(forWritingTo: url)
        try handle.truncate(atOffset: UInt64(size))
        try handle.close()
        
        printFlush("✅ Created \(sizeGB)GB disk image")
    }
    
    // MARK: - Install macOS
    @MainActor
    func installMacOS(restoreImageURL: URL, config: VZVirtualMachineConfiguration) async throws {
        printFlush("🚀 Starting macOS installation...")
        
        let vm = VZVirtualMachine(configuration: config)
        self.virtualMachine = vm
        vm.delegate = self
        
        let installer = VZMacOSInstaller(virtualMachine: vm, restoringFromImageAt: restoreImageURL)
        
        // Progress observation
        let observation = installer.progress.observe(\.fractionCompleted) { progress, _ in
            let percent = Int(progress.fractionCompleted * 100)
            print("\r📦 Installing: \(percent)%", terminator: "")
            fflush(stdout)
        }
        
        do {
            try await installer.install()
            observation.invalidate()
            printFlush("\n✅ macOS installation complete!")
        } catch {
            observation.invalidate()
            printFlush("\n❌ Installation failed: \(error)")
            printFlush("   \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Start VM
    @MainActor
    func startVM(config: VZVirtualMachineConfiguration) async throws {
        printFlush("🖥️  Starting Virtual Machine...")
        
        let vm = VZVirtualMachine(configuration: config)
        self.virtualMachine = vm
        vm.delegate = self
        
        try await vm.start()
        printFlush("✅ VM started successfully!")
    }
    
    // MARK: - VZVirtualMachineDelegate
    func virtualMachine(_ virtualMachine: VZVirtualMachine, didStopWithError error: Error) {
        printFlush("❌ VM stopped with error: \(error.localizedDescription)")
    }
    
    func guestDidStop(_ virtualMachine: VZVirtualMachine) {
        printFlush("🛑 Guest OS stopped")
    }
}

// MARK: - Errors
enum VMError: Error, LocalizedError {
    case noRestoreImageURL
    case unsupportedConfiguration
    case installationFailed
    
    var errorDescription: String? {
        switch self {
        case .noRestoreImageURL: return "No restore image URL available"
        case .unsupportedConfiguration: return "This Mac doesn't support the required configuration"
        case .installationFailed: return "macOS installation failed"
        }
    }
}

// Helper to flush print
func printFlush(_ message: String) {
    print(message)
    fflush(stdout)
}

// MARK: - Main Entry Point
@main
struct MacVMApp {
    static func main() async {
        printFlush("""
        ╔═══════════════════════════════════════╗
        ║     Mac Virtual Machine Manager       ║
        ║   Using Apple Virtualization Framework ║
        ╚═══════════════════════════════════════╝
        """)
        
        // Check Apple Silicon
        #if !arch(arm64)
        printFlush("❌ Error: This app requires Apple Silicon (M1/M2/M3)")
        return
        #endif
        
        let manager = MacVMManager(bundlePath: "~/MacVM.bundle")
        
        do {
            // 1. Create bundle
            try manager.createVMBundle()
            
            // 2. Download restore image
            let restoreImageURL = try await manager.downloadRestoreImage()
            
            // 3. Create configuration
            let config = try await manager.createConfiguration(restoreImageURL: restoreImageURL)
            
            // 4. Check args for install/boot mode
            let args = CommandLine.arguments
            if args.contains("--install") {
                printFlush("\n📦 Installing macOS...")
                try await manager.installMacOS(restoreImageURL: restoreImageURL, config: config)
            } else {
                printFlush("\n📦 Attempting to boot existing VM...")
                printFlush("   (Use --install flag to run installation)")
            }
            
            // 5. Start VM
            try await manager.startVM(config: config)
            
            // Keep running
            printFlush("\n💡 Press Ctrl+C to stop the VM")
            dispatchMain()
            
        } catch {
            printFlush("❌ Error: \(error.localizedDescription)")
        }
    }
}
