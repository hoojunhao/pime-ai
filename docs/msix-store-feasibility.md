# PIME 的 MSIX 與 Microsoft Store 上架可行性

> 本文件由 AI 助理孟慧（OpenAI GPT-5.6-sol）協助調查與撰寫。

## 結論

不建議只為了節省簽章費，把 PIME 全面改成 MSIX。

Microsoft Store 會替通過審核的 MSIX/AppX 自動簽章，因此 MSIX 不需要自行購買公開 CA 憑證；但 PIME 的核心是會被其他應用程式載入的 **in-process TSF COM DLL**。Microsoft 的 MSIX 文件指出，套件內模組不能以 in-process 方式載入不屬於同一套件的程序。這與 PIME 的運作方式直接衝突。

建議保留 NSIS 安裝器，使用專案現有的 SignPath 開源專案贊助簽章，再以傳統 EXE 形式上架 Microsoft Store。這條路徑可避免購買憑證，但原因是使用 SignPath sponsored signing，不是 Microsoft Store 替 EXE 簽章。

## PIME 為何不適合直接改成 MSIX

### 1. TSF DLL 必須載入其他應用程式

PIME 架構如下：

```text
一般 Windows 應用程式
  └─ 載入 PIMETextService.dll
       └─ Named Pipe
            └─ PIMELauncher.exe
                 └─ Python / Node backend
```

相關程式：

- `HACKING.txt`
- `PIMETextService/DllEntry.cpp`
- `libIME2/src/ImeModule.cpp`
- `PIMELauncher/src/main.rs`

Microsoft 的 MSIX 文件指出，套件模組不能以 in-process 方式載入不屬於該 package 的程序。但 TSF 正是由記事本、瀏覽器、Office 等各種程序載入 `PIMETextService.dll`。這不是只修改 package manifest 就能解決的問題。

### 2. 現有安裝需要執行 `regsvr32`

`installer/installer.nsi:648-670` 會分別註冊 x86、x64、ARM64 DLL：

```text
regsvr32.exe /s PIMETextService.dll
```

`libIME2/src/ImeModule.cpp` 的 `registerServer()` 還會：

- 寫入 `HKCR\CLSID\...\InprocServer32`
- 呼叫 `ITfInputProcessorProfiles::Register`
- 新增語言 profiles
- 呼叫 `ITfCategoryMgr::RegisterCategory`
- 修改所有使用者的語言設定
- 載入 Default User registry hive

MSIX 沒有一般 NSIS/MSI 那種任意安裝 custom action，不能在部署期間直接保留這套邏輯。

### 3. 需要管理員及 HKLM 系統修改

目前安裝器：

- 使用 `RequestExecutionLevel admin`
- 寫入 `HKLM\Software\PIME`
- 寫入 `HKLM\...\Run`
- 註冊 machine-wide COM
- 修改其他使用者的 registry hive

Microsoft Store 不接受 MSIX 將 elevation 作為必要功能；MSIX 的 HKLM 寫入也可能失敗或被虛擬化。

### 4. MSIX 安裝目錄唯讀

目前安裝流程會：

- 執行 Python `compileall`
- 在安裝目錄產生 `.pyc`
- 在安裝期間轉換部分輸入法字典
- 使用 `%ProgramFiles(x86)%\PIME` 固定路徑
- 讓部分 backend 以安裝目錄作為 working directory

MSIX 安裝位置位於受保護的 `WindowsApps`，執行期間不可修改。若要改成 MSIX，必須將 cache、設定及使用者字典全面移到 AppData，並移除固定安裝路徑假設。

### 5. 多架構 TSF DLL

x64 Windows 同時需要：

- x86 TSF DLL，供 32-bit 應用程式載入
- x64 TSF DLL，供 64-bit 應用程式載入

ARM64 還有更多原生與模擬架構組合。一般 MSIX bundle 通常依裝置架構選擇套件，不自然支援同一台電腦同時註冊多個架構、共用同一 CLSID 的 in-process COM/TSF DLL。

## Microsoft Store 簽章規則

### MSIX/AppX

Microsoft Store 會重新簽署送審通過的 MSIX/AppX：

- 不必購買 CA code-signing certificate
- 不必提供 `.pfx`
- 不必使用 USB token 或 HSM

這只能解決 package 簽章，不能解決 PIME 的 MSIX 架構相容性。

此外，Microsoft 的 IME 規範要求第三方 IME DLL 必須有數位簽章。即使嘗試 MSIX，最安全的做法仍是簽署 `PIMETextService.dll` 本身，而不是只依賴 package signature。

### 傳統 EXE/MSI

Microsoft Store 可以接受 `.exe` 或 `.msi`，但：

- Store 不會替 EXE/MSI 簽章。
- Installer 及其中所有 PE 檔案都必須有有效簽章。
- 憑證鏈必須連到 Microsoft Trusted Root Program 內的 CA。
- 必須支援無 UI 的 silent install。
- 必須是完整離線安裝器，不能在安裝時下載檔案。
- 必須使用不可覆蓋舊檔的版本化 HTTPS URL。

## 專案現有的免費簽章路徑

`.github/workflows/build-and-sign.yaml` 已整合 SignPath：

1. 簽署 `PIMELauncher.exe`。
2. 簽署 x86、x64、ARM64 `PIMETextService.dll`。
3. 建立 NSIS installer。
4. 再簽署 installer。
5. Release tag 使用 `release-signing` policy。

SignPath 對符合資格的開源專案提供 sponsored signing。因此，如果 PIME 的 SignPath production signing 已獲核准並可正常使用，原則上不需要自行購買憑證。

Repository 內現有的下列本機產物經檢查均為 `NotSigned`：

- `installer/PIME-2.0.0-beta2-setup.exe`
- `installer/PIME-2.0.0-beta3-setup.exe`

它們不代表正式 CI release；上架前必須由 release workflow 產生並驗證正式簽章。

## 上架 EXE 前需要處理的問題

### 1. 補簽所有 payload PE

目前掃描 `python/` 和 `node/` 發現下列檔案未簽章：

```text
python/input_methods/rime/rime.dll
python/libchewing/chewing.dll
python/opencc/opencc.dll
python/python3/Lib/site-packages/tornado/speedups.pyd
node/input_methods/emojime/node_modules/@esbuild/win32-x64/esbuild.exe
```

Microsoft Store 對 EXE 要求 installer 及其中所有 PE 都必須簽章。因此 CI 應在建立 NSIS installer 前一併簽署這些檔案，或排除不需要發佈的檔案。

建議另加 release gate：掃描所有 `.exe`、`.dll`、`.pyd`，只要發現無效或缺少簽章就讓 release build 失敗。

### 2. 改成完整離線安裝

`installer/installer.nsi` 的 `ensureVCRedist` 會從 `aka.ms` 下載並執行 VC++ Redistributable。這違反 Microsoft Store 的「standalone installer，不得在安裝時下載 bits」規定。

可採取：

- 將必要 runtime 納入 installer；或
- 確認所有元件已靜態連結或攜帶 app-local runtime，再移除下載流程。

頂層 `CMakeLists.txt` 已設定 `/MT`，embedded Python 也包含部分 runtime DLL，因此這段流程可能可以簡化，但必須在乾淨 Windows 10 VM 驗證。

### 3. 驗證完全靜默安裝

NSIS 原生支援 `/S`，但仍需確認：

- 不顯示語言選擇。
- 不顯示 VC runtime 問答。
- 不要求選擇六碼字典檔。
- 不顯示完成頁。
- 安裝失敗時透過 exit code 回報，而不是只顯示 MessageBox。

Store 允許 UAC，但不允許一般安裝 UI。

## 建議實施方案

### 推薦：NSIS + SignPath + Microsoft Store EXE

1. 保留目前 NSIS 安裝器，不進行高風險 MSIX 架構重寫。
2. 補齊 installer 內所有 PE 檔案的簽章。
3. 移除安裝期間的下載行為，改成完整離線安裝。
4. 驗證 `setup.exe /S` 完全靜默且能用 exit code 回報結果。
5. 使用正式 SignPath release policy 產出並驗證簽章。
6. 使用版本化 HTTPS URL，以 EXE 形式提交 Microsoft Store。

### 成本判斷

| 項目 | 預期成本 |
|---|---:|
| 新個人 Microsoft Store 開發者帳號 | 官方目前提供免費註冊 |
| Microsoft Store 替 EXE 簽章 | 不提供 |
| 自購公開 code-signing certificate | 使用 SignPath sponsored signing 時可不買 |
| MSIX 全面重構 | 高成本且可能不可行 |
| 現有 NSIS 修到符合 Store 規範 | 中低成本 |

公司帳號的驗證與費用政策可能不同，需依實際帳號類型確認。

## 最終決策

可以做到「不花錢購買簽章並上架 Microsoft Store」，但推薦路徑不是 MSIX：

```text
現有 NSIS EXE
  + SignPath 開源專案贊助簽章
  + 補簽所有內含 PE
  + 改成離線、靜默安裝
  + 以 EXE 形式提交 Microsoft Store
```

純 MSIX 只有在 Microsoft 明確提供「packaged third-party TSF in-process IME」的受支援部署方式後才值得投入。以目前官方文件和 PIME 架構判斷，全面移植的風險明顯高於保留 NSIS。

## 參考資料

- [Prepare to package a desktop application](https://learn.microsoft.com/en-us/windows/msix/desktop/desktop-to-uwp-prepare)
- [MSIX app package requirements](https://learn.microsoft.com/en-us/windows/apps/publish/publish-your-app/msix/app-package-requirements)
- [MSI/EXE app package requirements](https://learn.microsoft.com/en-us/windows/apps/publish/publish-your-app/msi/app-package-requirements)
- [Get started with Microsoft Store](https://learn.microsoft.com/en-us/windows/apps/publish/get-started)
- [Third-party input method editors](https://learn.microsoft.com/en-us/windows/compatibility/third-party-input-method-editors)
- [IME requirements](https://learn.microsoft.com/en-us/windows/apps/develop/input/input-method-editor-requirements)
- [Free developer registration for individual developers](https://learn.microsoft.com/en-us/windows/apps/publish/whats-new-individual-developer)
- [SignPath Open Source Community](https://signpath.io/solutions/open-source-community)
