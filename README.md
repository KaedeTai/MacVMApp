# MacVM

macOS 虛擬機管理工具，使用 Apple Virtualization Framework。

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)
![Apple Silicon](https://img.shields.io/badge/Apple%20Silicon-Required-red)
![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange)

## 功能

- 🖥️ 在 Mac 上運行 macOS 虛擬機
- 📥 自動下載最新 macOS 恢復映像
- 🎛️ SwiftUI 圖形化控制面板
- 🔊 支援音訊輸入/輸出
- 🌐 NAT 網路連線
- 💾 可配置磁碟大小 (預設 80GB)

## 系統需求

- Apple Silicon Mac (M1/M2/M3/M4)
- macOS 14.0 Sonoma 或更新版本
- 至少 16GB RAM（建議）
- 100GB+ 可用磁碟空間

## 安裝

### 從原始碼編譯

```bash
git clone https://github.com/yourusername/MacVMAppGUI.git
cd MacVMAppGUI
./build.sh
```

編譯完成後，app 會在 `.build/MacVM.app`。

### 複製到 Applications

```bash
cp -R .build/MacVM.app /Applications/
```

## 使用方式

1. **啟動 MacVM.app**
   - 雙擊 `/Applications/MacVM.app`
   - 會出現控制面板視窗

2. **下載 IPSW**
   - 點擊「下載 IPSW」按鈕
   - 等待下載完成（約 13-15GB）

3. **安裝 macOS**
   - 點擊「安裝 macOS」按鈕
   - 安裝過程約 15-30 分鐘

4. **啟動 VM**
   - 點擊「啟動」按鈕
   - 點擊「開啟 VM 視窗」查看畫面

## 檔案結構

所有 VM 資料儲存在 `~/MacVM.bundle/`：

```
~/MacVM.bundle/
├── RestoreImage.ipsw    # macOS 恢復映像 (~14GB)
├── Disk.img             # 虛擬磁碟 (80GB)
├── AuxiliaryStorage     # 輔助儲存
├── MachineIdentifier    # 機器識別碼
└── HardwareModel        # 硬體模型資料
```

## VM 配置

| 項目 | 預設值 |
|------|--------|
| CPU | 4 核心（最少） |
| 記憶體 | 8 GB（最少） |
| 磁碟 | 80 GB |
| 顯示 | 1920 x 1200 @ 144 PPI |
| 網路 | NAT |
| 音訊 | 雙向（輸入/輸出） |

## 開發

### 專案結構

```
MacVMAppGUI/
├── Package.swift
├── Sources/
│   ├── MacVMApp.swift      # App 入口 + SwiftUI 視圖
│   ├── VMManager.swift     # VM 管理邏輯
│   ├── VMNativeView.swift  # VM 畫面顯示
│   └── Info.plist
├── MacVMAppGUI.entitlements
└── build.sh
```

### 編譯指令

```bash
# Debug
swift build

# Release
swift build -c release

# 完整 build（含簽署和打包）
./build.sh
```

### Entitlements

需要以下權限：
- `com.apple.security.virtualization` - 虛擬化框架

## 疑難排解

### VM 無法啟動

確認：
1. 是 Apple Silicon Mac
2. macOS 14.0+
3. 已完成安裝步驟
4. 磁碟空間足夠

### 安裝卡住

- 檢查 `~/MacVM.bundle/Disk.img` 大小
- 若小於 20GB 表示安裝未完成
- 刪除整個 `~/MacVM.bundle` 重新開始

### 效能問題

- 關閉其他大型應用
- 確保 Mac 接上電源
- 檢查活動監視器的 CPU/記憶體使用

## 授權

MIT License

## 相關連結

- [Apple Virtualization Framework](https://developer.apple.com/documentation/virtualization)
- [Running macOS in a virtual machine on Apple silicon](https://developer.apple.com/documentation/virtualization/running_macos_in_a_virtual_machine_on_apple_silicon)
