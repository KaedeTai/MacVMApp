import SwiftUI
import Virtualization
import AppKit

// 原生 NSViewRepresentable - 直接使用 VZVirtualMachineView
struct VMNativeView: NSViewRepresentable {
    let virtualMachine: VZVirtualMachine
    
    func makeNSView(context: Context) -> VZVirtualMachineView {
        let view = VZVirtualMachineView()
        view.virtualMachine = virtualMachine
        view.capturesSystemKeys = true
        view.automaticallyReconfiguresDisplay = true
        return view
    }
    
    func updateNSView(_ nsView: VZVirtualMachineView, context: Context) {
        nsView.virtualMachine = virtualMachine
        
        // 確保視窗獲得焦點
        DispatchQueue.main.async {
            nsView.window?.makeKey()
            nsView.window?.makeFirstResponder(nsView)
        }
    }
}

// 備用：控制面板中的 VM 預覽（不用於輸入）
struct VMDisplayView: View {
    @EnvironmentObject var vmManager: VMManager
    @Environment(\.openWindow) private var openWindow
    
    var body: some View {
        VStack {
            if vmManager.isRunning {
                VStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.green)
                    Text("VM 運行中")
                        .font(.title2)
                    Button("開啟 VM 視窗") {
                        openWindow(id: "vm-display")
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                VStack {
                    Image(systemName: "desktopcomputer")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("VM 未運行")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
