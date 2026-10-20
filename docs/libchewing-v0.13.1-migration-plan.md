<!-- Generated with assistance from OpenAI GPT-5.6. -->

# libchewing v0.13.1 遷移計畫

## 目標

將 PIME 新酷音從舊版 libchewing 遷移至 Codeberg 的穩定版
`v0.13.1`，保留 Windows 10、x86 Python backend 與主要輸入行為，並建立
可重現的 DLL、系統詞庫及安裝檔建置流程。既有 `chewing.sqlite3` 會先建立
一次性備份，再交由 v0.13.1 的上游 migration 轉換。

固定版本：

| 元件 | Repository | Commit |
| --- | --- | --- |
| libchewing `v0.13.1` | `https://codeberg.org/chewing/libchewing.git` | `f071d2e95c531cc39bb4325cd5a5d0e1d51daef8` |
| libchewing-data | `https://codeberg.org/chewing/libchewing-data.git` | `bfba418ea8a4bd2fe10b9bf80b4bf81ec01af5f4` |

本機參考 clone 位於 `../libchewing`。正式建置仍以 PIME 的 `libchewing`
submodule 固定 commit 為準，不依賴該外部目錄。

## 導入結果

目前實作位於 `feature/libchewing-v0.13.1`，已完成程式、詞庫、建置流程、
授權、SQLite 使用者詞庫與 NSIS installer 產物。安裝後的人工 TSF 測試
尚未完成。

| 項目 | 結果 | 證據 |
| --- | --- | --- |
| 固定上游版本 | 完成 | libchewing 與 data commit 符合上表 |
| Windows x86 runtime | 完成 | `chewing.dll` PE Machine `0x014c`，bundled x86 Python 可載入 |
| SQLite link | 完成 | SQLite 靜態連結，無 `sqlite3.dll` runtime dependency |
| Python C ABI | 完成 | 所有 PIME 使用中的 API 已宣告 `argtypes`、`restype` |
| 新版系統詞庫 | 完成 | 已改用 `word.dat`、`tsi.dat`、`symbols.dat`、`swkb.dat` |
| PIME 附加詞庫 | 完成 | `pime.dat` 包含「馬斯克」，真實 DLL 候選測試通過 |
| PIME AI 附加詞庫 | 完成 | `pime-ai.dat` 包含「伊隆馬斯克」，真實 DLL 候選測試通過 |
| 完整 PIME build | 完成 | x86、x64、ARM64 及 Node 輸入法建置成功 |
| NSIS installer | 完成建置 | payload 包含新版 DLL、系統詞庫、`pime.dat` 與 `pime-ai.dat` |
| Fresh install 人工測試 | 尚未執行 | 尚未在測試機完成 TSF 註冊、輸入及 uninstall |
| SQLite 使用者詞庫 | 完成 | carried patch 修正 usage；新增、重開、刪除與雙 context 測試通過 |
| 舊詞庫遷移 | 完成自動化路徑 | 先驗證 `.pre-v0.13.1.bak`，再由 v0.13.1 migration 轉換；明確選取的低頻候選會立即升至同音最高頻率以上 |

### 產物

```text
python/libchewing/chewing.dll
python/libchewing/data/word.dat
python/libchewing/data/tsi.dat
python/libchewing/data/symbols.dat
python/libchewing/data/swkb.dat
python/libchewing/data/dictionary.d/pime.dat
python/libchewing/data/dictionary.d/pime-ai.dat
installer/PIME-2.0.0-beta3-setup.exe
```

目前產物 SHA-256：

```text
chewing.dll
5de04f92643db9f8ecf65d9290a3e181cb4af0c2a59509df247e4f80fee41a08

pime.dat
2a30fcfbf05208d9aa43b2978843085c00fb69386b0335c62874a850d60b74e6

pime-ai.dat
436bce03ae57ac53a17226ff7e041e0f1999576a5feb6f4a3fb95c0475cd9ac8

PIME-2.0.0-beta3-setup.exe
cc4e3cdff39d99139ca7b805bda59f5fbe0e5987ddf7b70a6fb0ead5b3375235
```

### 自動化驗證

| 測試 | 結果 |
| --- | --- |
| libchewing native x86 tests | 14 個 test executables 全部通過 |
| Rust core | 107 passed |
| Rust C API | 107 passed |
| `chewing-cli` | 103 passed |
| Python backend、詞庫驗證與 libchewing binding | 18 passed |
| PIME native CTest | 2 passed |
| 完整 `build.bat` | x86、x64、ARM64 與 Node targets 全部成功 |
| Installer license freshness | 通過 |
| NSIS payload | 新檔各 1 份，舊詞庫檔各 0 份 |

NSIS payload 檢查結果：

```text
chewing.dll=1
word.dat=1
tsi.dat=1
pime.dat=1
pime-ai.dat=1
dictionary.dat=0
index_tree.dat=0
pinyin.tab=0
```

### 導入 commits

```text
576433d Plan libchewing v0.13.1 migration
a0b2452 Pin libchewing v0.13.1 from Codeberg
c56822c Build libchewing v0.13.1 for x86
e55df19 Declare the libchewing Python ABI
b402cdd Add PIME Chewing extension dictionary
98e97cb Bundle libchewing runtime licenses
8ec4a51 Document the supported libchewing scope
184c3c4 Make the full build fail fast
02bcea5 Harden backend error replies
aaf9a28 Merge backend error handling fix
69e8b06 Merge backend fix from Windows
aae6d23 Separate the PIME AI Chewing dictionary
```

### 已知限制

- 尚未執行 installer 的實際 fresh install、TSF 註冊、記事本輸入、
  reboot、uninstall 與 rollback 測試。
- 尚未執行多程序同時寫入 SQLite 的壓力測試。
- v0.13.1 沒有公開的手動調頻 API；Ctrl+PageUp／PageDown 會顯示不支援，
  不再直接修改私有 SQLite schema。
- NSIS 仍有既有的 `mui.ComponentsPage.DescriptionText` warning，不影響產物生成。
- Node 建置有既有 npm audit 項目，本次未混入第三方依賴升級。

## 已知差異

1. libchewing 已由舊 C 實作轉為 Rust core 加 C ABI，建置需要 CMake 3.27、
   Rust 1.88、MSVC 及 Corrosion。
2. 系統詞庫由 `dictionary.dat`、`index_tree.dat` 改成 `word.dat`、`tsi.dat`；
   原始資料由 `phone.cin`、`tsi.src` 改成 `word.csv`、`tsi.csv`。
3. PIME backend 是 x86 Python，因此必須建置
   `i686-pc-windows-msvc` 的 DLL；上游目前沒有 Windows x86 CI 證據。
4. 新版 SQLite 使用 `dictionary_v1`、`userphrase_v2` 等表。PIME 不再直接
   讀寫這些私有 schema；舊 `userphrase_v1` 僅由上游 migration 讀取。
5. MSVC 產物名為 `chewing-msvc.dll`，PIME wrapper 現在載入
   `python/libchewing/chewing.dll`。
6. 根目錄 `build.bat` 現已先建置及同步 libchewing runtime，並在任一
   CMake、npm 或 artifact copy 步驟失敗時立即停止。

## 範圍

### 包含

- 更新 libchewing submodule URL 與固定版本。
- 建立可重現的 Windows x86、SQLite-enabled 建置及 artifact 同步流程。
- 更新 Python `ctypes` 宣告。
- 修正 SQLite user dictionary usage，並在遷移舊資料前建立可驗證備份。
- 打包新版 DLL、詞庫與必要授權。
- 提供 PIME 與 PIME AI 分層附加詞庫的來源與建置流程。

### 不包含

- 將 Python backend 遷移至 x64。
- 改寫其他輸入法。
- 追蹤 libchewing `master` 或 alpha release。
- 在同一變更中進行無關重構。
- 提供 v0.13.1 未公開的手動調頻 API。

## 驗收條件

1. **版本固定**：fresh clone 執行 recursive submodule update 後，libchewing
   與 data commit 分別符合上表。
2. **x86 artifact**：建置產生可由 bundled x86 Python 載入的
   `chewing.dll`，PE Machine 為 `0x014c`，且不缺少 runtime DLL。
3. **系統詞庫**：安裝內容使用同 revision 產生的 `word.dat`、`tsi.dat`、
   `symbols.dat`、`swkb.dat`，一般注音及 PIME 附加詞均可成為候選。
4. **輸入行為**：一般組字、選字、翻頁、commit 與點字新酷音
   的主要路徑通過實機 smoke test。
5. **安裝升級**：Windows 10 上的全新安裝成功；安裝包不混用新舊 DLL
   或系統詞庫。舊使用者詞庫須先建立有效備份，再允許上游 migration。

## 實作階段

### 1. 固定依賴

**結果：完成。**

- 將 `.gitmodules` 的 libchewing URL 改至 Codeberg。
- 將 submodule 固定於 `v0.13.1` commit。
- 以 recursive submodule 初始化固定的 libchewing-data。
- 此階段只處理 repository metadata，不混入 runtime 修改。

### 2. 建立 x86 build pipeline

**結果：完成。**

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

**結果：完成。**

- 在 `python/libchewing/libchewing.py` 明確宣告所有使用中函式的
  `argtypes` 與 `restype`，context 使用 `c_void_p`。
- 核對 `chewing_new2`、字串 ownership、iterator、buffer length 與 callback。
- 保留 `_static` API 只作相容過渡；新程式優先採用可釋放 buffer 的新版 API。
- 加入最低限度 ABI smoke test：載入 DLL、建立 context、取得版本、輸入、
  取得候選及釋放 context。

### 4. 使用者詞庫持久化與遷移

**結果：自動化路徑完成；多程序壓力與人工升級測試尚未執行。**

- 建置時套用最小 carried patch，讓 `SqliteDictionary::set_usage()` 正確
  設為 `User`；建置後還原並檢查 submodule 為乾淨狀態。
- 首次開啟舊 `%APPDATA%\PIME\chewing\chewing.sqlite3` 前，建立並驗證
  `chewing.sqlite3.pre-v0.13.1.bak`，備份失敗時停止 migration。
- 舊資料轉換沿用 v0.13.1 的 `userphrase_v1` migration，不由 PIME 重寫
  SQLite schema。
- 建置時套用 learning patch；遷移後若使用者明確提交低於同音最高頻率的
  既有候選，將該候選提升至最高頻率加 10，避免舊頻率尺度使偏好無法翻轉。
- Ctrl+Delete 先透過公開 enumeration 取得讀音，再呼叫
  `chewing_userphrase_remove()`；手動調頻暫停支援。
- SQLite 模式不再混載 `chewing.dat` 或 `chewing-deleted.dat`。

### 5. 建立 PIME 附加詞庫

**結果：完成。**

- 在 PIME 保存可審查的 UTF-8 CSV 原始檔，不直接修改產生的 `.dat`。
- 使用同版 `chewing-cli` 產生附加詞庫，安裝至
  `python/libchewing/data/dictionary.d/`。
- 首批詞彙包含已確認缺少的現代詞，並檢查詞彙字數、注音音節數與重複項。
- PIME 詞彙保存在 `data/chewing/pime.csv`；僅由此 fork 維護的詞彙
  保存在 `data/chewing/pime-ai.csv`，兩者分別產生 `pime.dat` 與
  `pime-ai.dat`。
- 建置前檢查兩層詞庫的欄位、詞彙字數、注音音節數及與上游詞庫的重複項。
- 以實際候選結果驗證附加詞庫載入；若 `chewing_new2` 不載入附加詞庫，
  改用 `chewing_new3` 並明確指定 dictionary names。

### 6. Installer、授權與文件

**結果：自動化建置與 payload 驗證完成；人工安裝驗證尚未執行。**

- 確認 installer 僅打包新版完整 artifact set，升級時清除已淘汰的舊系統詞庫。
- 將 Rust crates、libchewing-data 與 SQLite 的必要授權納入產物。
- 更新 README 的工具需求、建置命令及 troubleshooting。
- 人工測試 fresh install、使用者資料 upgrade／rollback 與 uninstall。

## 驗證順序

1. [x] 執行 libchewing upstream tests、SQLite persistence 與 PIME ABI smoke test。
2. [x] 用 bundled x86 Python 驗證 DLL architecture、exports 與 context lifecycle。
3. [ ] 執行新酷音與點字新酷音的手動輸入矩陣。
4. [x] 建置 NSIS installer。
5. [ ] 於 Windows 10 測試機驗證全新安裝、TSF 註冊與 uninstall。

## 提交拆分

每一階段使用獨立 commit。submodule URL／pointer、build pipeline、Python ABI、
附加詞庫及 installer 文件不得混成一個大型提交。每個 commit 需包含 WHAT、
WHY 與 AI assistance declaration。

## 回復策略

- 舊 `chewing.sqlite3` 在 migration 前保留一次性備份；發生問題時先停止
  PIME，再以該備份回復，不可只降級 DLL 後繼續使用已轉換資料庫。
- 每次啟動只允許同 revision 的 DLL 與系統詞庫組合；版本不符時拒絕啟動新酷音。
- 發佈前保留可重新產生舊 runtime bundle 的 tag。若新版發生阻斷問題，回復整組
  DLL、data 與 Python integration，不單獨降級其中一項。
