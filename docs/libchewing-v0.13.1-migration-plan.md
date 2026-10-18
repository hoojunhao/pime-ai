<!-- Generated with assistance from OpenAI GPT-5.6. -->

# libchewing v0.13.1 遷移計畫

## 目標

將 PIME 新酷音從舊版 libchewing 遷移至 Codeberg 的穩定版
`v0.13.1`，保留 Windows 10、x86 Python backend、既有使用者詞庫與主要輸入
行為，並建立可重現的 DLL、系統詞庫及安裝檔建置流程。

固定版本：

| 元件 | Repository | Commit |
| --- | --- | --- |
| libchewing `v0.13.1` | `https://codeberg.org/chewing/libchewing.git` | `f071d2e95c531cc39bb4325cd5a5d0e1d51daef8` |
| libchewing-data | `https://codeberg.org/chewing/libchewing-data.git` | `bfba418ea8a4bd2fe10b9bf80b4bf81ec01af5f4` |

本機參考 clone 位於 `../libchewing`。正式建置仍以 PIME 的 `libchewing`
submodule 固定 commit 為準，不依賴該外部目錄。

## 已知差異

1. libchewing 已由舊 C 實作轉為 Rust core 加 C ABI，建置需要 CMake 3.27、
   Rust 1.88、MSVC 及 Corrosion。
2. 系統詞庫由 `dictionary.dat`、`index_tree.dat` 改成 `word.dat`、`tsi.dat`；
   原始資料由 `phone.cin`、`tsi.src` 改成 `word.csv`、`tsi.csv`。
3. PIME backend 是 x86 Python，因此必須建置
   `i686-pc-windows-msvc` 的 DLL；上游目前沒有 Windows x86 CI 證據。
4. 新版 SQLite 使用 `dictionary_v1`、`userphrase_v2` 等表。PIME 現在直接
   讀寫 `userphrase_v1`、`config_v1`，不能原樣保留。
5. MSVC 產物名為 `chewing-msvc.dll`，PIME wrapper 現在載入
   `python/libchewing/chewing.dll`。
6. 根目錄 `build.bat` 尚未建置 libchewing 或同步其 runtime artifacts。

## 範圍

### 包含

- 更新 libchewing submodule URL 與固定版本。
- 建立可重現的 Windows x86、SQLite-enabled 建置及 artifact 同步流程。
- 更新 Python `ctypes` 宣告及使用者詞庫操作。
- 遷移舊 `chewing.sqlite3`，保留使用者詞彙。
- 打包新版 DLL、詞庫與必要授權。
- 提供 PIME 自有附加詞庫的來源與建置流程。

### 不包含

- 將 Python backend 遷移至 x64。
- 改寫其他輸入法。
- 追蹤 libchewing `master` 或 alpha release。
- 在同一變更中進行無關重構。

## 驗收條件

1. **版本固定**：fresh clone 執行 recursive submodule update 後，libchewing
   與 data commit 分別符合上表。
2. **x86 artifact**：建置產生可由 bundled x86 Python 載入的
   `chewing.dll`，PE Machine 為 `0x014c`，且不缺少 runtime DLL。
3. **系統詞庫**：安裝內容使用同 revision 產生的 `word.dat`、`tsi.dat`、
   `symbols.dat`、`swkb.dat`，一般注音及 PIME 附加詞均可成為候選。
4. **使用者資料**：全新啟動可建立資料庫；既有 `userphrase_v1`
   資料庫可先備份再遷移，原有詞彙仍可列舉及選取。
5. **輸入行為**：一般組字、選字、翻頁、commit、Ctrl+數字加詞與點字新酷音
   的主要路徑通過實機 smoke test。
6. **設定工具**：使用者詞庫新增、刪除、列舉、匯入及匯出不依賴已淘汰的
   schema，且不會覆寫正在使用中的 SQLite 檔案。
7. **安裝升級**：Windows 10 上的全新安裝與保留 `%APPDATA%` 的升級安裝
   均成功；安裝包不混用新舊 DLL 或詞庫。

## 實作階段

### 1. 固定依賴

- 將 `.gitmodules` 的 libchewing URL 改至 Codeberg。
- 將 submodule 固定於 `v0.13.1` commit。
- 以 recursive submodule 初始化固定的 libchewing-data。
- 此階段只處理 repository metadata，不混入 runtime 修改。

### 2. 建立 x86 build pipeline

- 使用 VS 2022、CMake 3.27+、Rust 1.88 與
  `i686-pc-windows-msvc`。
- 啟用 shared library、SQLite 與 data build。
- 明確設定 Win32/vcpkg triplet；不要使用上游預設的 x64 開發命令。
- 將 `chewing-msvc.dll` 以 PIME runtime 名稱 `chewing.dll` 複製至
  `python/libchewing/`。
- 將 `word.dat`、`tsi.dat`、`symbols.dat`、`swkb.dat` 複製至
  `python/libchewing/data/`，並移除不再使用的舊資料。
- 讓 `build.bat` 呼叫獨立的 libchewing build script；script 應在 artifact
  缺漏或架構錯誤時立即失敗。

### 3. 固化 Python C ABI

- 在 `python/libchewing/libchewing.py` 明確宣告所有使用中函式的
  `argtypes` 與 `restype`，context 使用 `c_void_p`。
- 核對 `chewing_new2`、字串 ownership、iterator、buffer length 與 callback。
- 保留 `_static` API 只作相容過渡；新程式優先採用可釋放 buffer 的新版 API。
- 加入最低限度 ABI smoke test：載入 DLL、建立 context、取得版本、輸入、
  取得候選及釋放 context。

### 4. 遷移使用者詞庫

- 啟用新版 SQLite feature，繼續使用完整檔案路徑
  `%APPDATA%\PIME\chewing\chewing.sqlite3`。
- 第一次開啟前建立一次性備份；遷移失敗時保留原檔並回報錯誤。
- 移除 `chewing_ime.py` 與 `config_tool.py` 對 `userphrase_v1`、
  `config_v1` 的直接 SQL。
- 刪除與列舉改用公開 userphrase API。
- 若新版沒有公開的調高／調低詞頻 API，不得操作內部 schema；先以清楚訊息
  停用快捷鍵，再另案向上游提出 API 或設計可維護的替代方案。
- 匯入流程先關閉 context、驗證可開啟性並原子替換，再重新建立 context；
  匯出前確保 WAL 內容已 checkpoint。

### 5. 建立 PIME 附加詞庫

- 在 PIME 保存可審查的 UTF-8 CSV 原始檔，不直接修改產生的 `.dat`。
- 使用同版 `chewing-cli` 產生附加詞庫，安裝至
  `python/libchewing/data/dictionary.d/`。
- 首批詞彙包含已確認缺少的現代詞，並檢查詞彙字數、注音音節數與重複項。
- 以實際候選結果驗證附加詞庫載入；若 `chewing_new2` 不載入附加詞庫，
  改用 `chewing_new3` 並明確指定 dictionary names。

### 6. Installer、授權與文件

- 確認 installer 僅打包新版完整 artifact set，升級時清除已淘汰的舊系統詞庫。
- 將 Rust crates、libchewing-data 與 SQLite 的必要授權納入產物。
- 更新 README 的工具需求、建置命令及 troubleshooting。
- 分別測試 fresh install、upgrade、uninstall 與 rollback。

## 驗證順序

1. 執行 libchewing upstream tests 與 PIME ABI smoke test。
2. 用 bundled x86 Python 驗證 DLL architecture、exports 與 context lifecycle。
3. 以暫存目錄測試全新資料庫及舊資料庫 migration。
4. 執行新酷音、點字新酷音及設定工具的手動輸入矩陣。
5. 建置 NSIS installer，於 Windows 10 驗證全新安裝與升級安裝。

## 提交拆分

每一階段使用獨立 commit。submodule URL／pointer、build pipeline、Python ABI、
資料庫 migration、附加詞庫及 installer 文件不得混成一個大型提交。每個 commit
需包含 WHAT、WHY 與 AI assistance declaration。

## 回復策略

- migration 前保留原 `chewing.sqlite3` 備份，不做破壞性反向轉換。
- 每次啟動只允許同 revision 的 DLL 與系統詞庫組合；版本不符時拒絕啟動新酷音。
- 發佈前保留可重新產生舊 runtime bundle 的 tag。若新版發生阻斷問題，回復整組
  DLL、data 與 Python integration，不單獨降級其中一項。

