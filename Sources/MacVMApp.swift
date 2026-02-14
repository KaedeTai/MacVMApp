import SwiftUI

@main
struct MacVMApp: App {
    @StateObject private var vmManager = VMManager()
    
    var body: some Scene {
        // 控制面板視窗
        WindowGroup("MacVM 控制面板") {
            ControlPanel()
                .environmentObject(vmManager)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 400, height: 600)
        
        // VM 顯示視窗（獨立）
        WindowGroup("macOS VM", id: "vm-display") {
            VMWindowView()
                .environmentObject(vmManager)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1920, height: 1200)
    }
}

// 開啟 VM 視窗按鈕
struct OpenVMWindowButton: View {
    @Environment(\.openWindow) private var openWindow
    
    var body: some View {
        Button(action: { openWindow(id: "vm-display") }) {
            Label("開啟 VM 視窗", systemImage: "macwindow")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
    }
}

// VM 獨立視窗
struct VMWindowView: View {
    @EnvironmentObject var vmManager: VMManager
    
    var body: some View {
        Group {
            if vmManager.isRunning, let vm = vmManager.virtualMachine {
                VMNativeView(virtualMachine: vm)
            } else {
                VStack {
                    Image(systemName: "desktopcomputer")
                        .font(.system(size: 64))
                        .foregroundColor(.secondary)
                    Text("VM 未運行")
                        .font(.title2)
                    Text("請從控制面板啟動")
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

struct ControlPanel: View {
    @EnvironmentObject var vmManager: VMManager
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            VStack {
                Image(systemName: "desktopcomputer")
                    .font(.system(size: 36))
                    .foregroundColor(.blue)
                Text("Mac VM")
                    .font(.title2)
                    .fontWeight(.bold)
            }
            .padding(.top)
            
            Divider()
            
            // Status
            GroupBox("狀態") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("IPSW:")
                        Spacer()
                        Text(vmManager.ipswStatus)
                    }
                    HStack {
                        Text("VM:")
                        Spacer()
                        Text(vmManager.vmStateText)
                            .foregroundColor(vmManager.vmStateColor)
                    }
                }
                .font(.system(.body, design: .monospaced))
                .padding(8)
            }
            
            // Progress
            if vmManager.isDownloading {
                ProgressView(value: vmManager.downloadProgress) {
                    Text("下載中 \(Int(vmManager.downloadProgress * 100))%")
                }
            }
            if vmManager.isInstalling {
                ProgressView(value: vmManager.installProgress) {
                    Text("安裝中 \(Int(vmManager.installProgress * 100))%")
                }
            }
            
            // Actions
            GroupBox("操作") {
                VStack(spacing: 10) {
                    Button(action: { Task { await vmManager.downloadIPSW() } }) {
                        Label("下載 IPSW", systemImage: "arrow.down.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(vmManager.hasIPSW || vmManager.isDownloading)
                    
                    Button(action: { Task { await vmManager.installMacOS() } }) {
                        Label("安裝 macOS", systemImage: "externaldrive.badge.plus")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(!vmManager.hasIPSW || vmManager.isInstalling || vmManager.isInstalled)
                    
                    HStack {
                        Button(action: { Task { await vmManager.startVM() } }) {
                            Label("啟動", systemImage: "play.circle")
                        }
                        .disabled(!vmManager.isInstalled || vmManager.isRunning)
                        
                        Button(action: { vmManager.stopVM() }) {
                            Label("停止", systemImage: "stop.circle")
                        }
                        .disabled(!vmManager.isRunning)
                    }
                    
                    OpenVMWindowButton()
                        .disabled(!vmManager.isRunning)
                }
                .padding(8)
            }
            
            // Logs
            GroupBox("日誌") {
                ScrollView {
                    ScrollViewReader { proxy in
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(vmManager.logs.indices, id: \.self) { index in
                                Text(vmManager.logs[index])
                                    .font(.system(.caption2, design: .monospaced))
                                    .id(index)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .onChange(of: vmManager.logs.count) { _, _ in
                            if let last = vmManager.logs.indices.last {
                                proxy.scrollTo(last, anchor: .bottom)
                            }
                        }
                    }
                }
                .frame(maxHeight: 200)
                .padding(4)
                .background(Color.black.opacity(0.05))
                .cornerRadius(4)
            }
            
            Spacer()
        }
        .padding()
    }
}
