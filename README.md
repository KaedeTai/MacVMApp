# Mac VM App

使用 Apple Virtualization Framework 在 Apple Silicon Mac 上運行 macOS 虛擬機。

## 系統需求

- **Apple Silicon Mac** (M1/M2/M3/M4)
- **macOS 13.0+** (Ventura 或更新)
- **Xcode 14+**
- 至少 **16GB RAM**（建議）
- 至少 **100GB 可用空間**（用於 IPSW + 虛擬磁碟）

## 權限設定

此 App 需要 `com.apple.security.virtualization` 權限。

### 方法 1：簽名運行（推薦）

```bash
# 編譯
swift build -c release

# 簽名
codesign --entitlements MacVMApp.entitlements --force -s - .build/release/MacVMApp

# 運行
.build/release/MacVMApp
```

### 方法 2：關閉 SIP（不推薦）

僅用於開發測試。

## 專案結構

```
MacVMApp/
├── Package.swift           # Swift Package 配置
├── MacVMApp.entitlements   # 權限配置
├── README.md
└── Sources/
    ├── main.swift          # CLI 版本 (預設)
    └── MacVMAppGUI.swift   # SwiftUI GUI 版本
```

## 使用方式

### CLI 版本

```bash
cd ~/Projects/MacVMApp
swift build -c release
codesign --entitlements MacVMApp.entitlements --force -s - .build/release/MacVMApp
.build/release/MacVMApp
```

程式會：
1. 在 `~/MacVM.bundle/` 建立 VM 資料夾
2. 下載最新 macOS 恢復映像（約 13GB）
3. 建立 64GB 虛擬磁碟
4. 安裝並啟動 macOS VM

### GUI 版本

1. 編輯 `Sources/MacVMAppGUI.swift`
2. 取消 `@main` 註解
3. 註解掉 `Sources/main.swift` 的 `@main`
4. 重新編譯

## VM 配置

| 設定 | 預設值 |
|------|--------|
| CPU | 4 核心 |
| RAM | 8 GB |
| 磁碟 | 64 GB |
| 顯示 | 1920x1200 |
| 網路 | NAT |

## 檔案位置

- VM Bundle: `~/MacVM.bundle/`
- 恢復映像: `~/MacVM.bundle/RestoreImage.ipsw`
- 虛擬磁碟: `~/MacVM.bundle/Disk.img`
- 輔助儲存: `~/MacVM.bundle/AuxiliaryStorage`

## 注意事項

⚠️ 首次運行需要下載約 **13GB** 的 macOS 恢復映像
⚠️ 安裝過程約需 **30-60 分鐘**
⚠️ 確保有足夠的磁碟空間

## 參考資料

- [Apple Virtualization Framework](https://developer.apple.com/documentation/virtualization)
- [Running macOS in a virtual machine on Apple silicon](https://developer.apple.com/documentation/virtualization/running_macos_in_a_virtual_machine_on_apple_silicon)

## License

MIT
