import SwiftUI
import Virtualization

struct ContentView: View {
    @EnvironmentObject var vmManager: VMManager
    @State private var showingVMWindow = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: "desktopcomputer")
                    .font(.system(size: 48))
                    .foregroundColor(.blue)
                VStack(alignment: .leading) {
                    Text("Mac Virtual Machine")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("Powered by Apple Virtualization Framework")
                        .foregroundColor(.secondary)
                }
            }
            .padding(.top, 30)
            
            Divider()
            
            // Status
            GroupBox("狀態") {
                VStack(alignment: .leading, spacing: 10) {
                    StatusRow(label: "VM Bundle", value: vmManager.bundlePath)
                    StatusRow(label: "IPSW", value: vmManager.ipswStatus)
                    StatusRow(label: "VM 狀態", value: vmManager.vmStateText, color: vmManager.vmStateColor)
                    
                    if vmManager.isDownloading {
                        ProgressView(value: vmManager.downloadProgress) {
                            Text("下載中... \(Int(vmManager.downloadProgress * 100))%")
                        }
                    }
                    
                    if vmManager.isInstalling {
                        ProgressView(value: vmManager.installProgress) {
                            Text("安裝中... \(Int(vmManager.installProgress * 100))%")
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            
            // Actions
            GroupBox("操作") {
                HStack(spacing: 15) {
                    Button(action: { Task { await vmManager.downloadIPSW() } }) {
                        Label("下載 IPSW", systemImage: "arrow.down.circle")
                    }
                    .disabled(vmManager.hasIPSW || vmManager.isDownloading)
                    
                    Button(action: { Task { await vmManager.installMacOS() } }) {
                        Label("安裝 macOS", systemImage: "externaldrive.badge.plus")
                    }
                    .disabled(!vmManager.hasIPSW || vmManager.isInstalling || vmManager.isInstalled)
                    
                    Button(action: { Task { await vmManager.startVM() } }) {
                        Label("啟動 VM", systemImage: "play.circle")
                    }
                    .disabled(!vmManager.isInstalled || vmManager.isRunning)
                    
                    Button(action: { vmManager.stopVM() }) {
                        Label("停止 VM", systemImage: "stop.circle")
                    }
                    .disabled(!vmManager.isRunning)
                }
                .padding()
            }
            
            // Logs
            GroupBox("日誌") {
                ScrollView {
                    ScrollViewReader { proxy in
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(vmManager.logs.indices, id: \.self) { index in
                                Text(vmManager.logs[index])
                                    .font(.system(.caption, design: .monospaced))
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
                .frame(height: 200)
                .padding(8)
                .background(Color.black.opacity(0.05))
                .cornerRadius(8)
            }
            
            Spacer()
        }
        .padding()
        .frame(minWidth: 600, minHeight: 500)
    }
}

struct StatusRow: View {
    let label: String
    let value: String
    var color: Color = .primary
    
    var body: some View {
        HStack {
            Text(label + ":")
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .foregroundColor(color)
        }
    }
}

// Preview removed for SPM compatibility
