<!-- Generated with assistance from OpenAI GPT-5.6. -->

# Python backend 位元架構與 x64 效能評估

## 結論

PIME 目前隨附的 Python backend 是 **32-bit x86**。改用 x64 技術上可行，也不要求同步將 `PIMELauncher.exe` 改成 x64；但必須同時替換所有 Python 原生 DLL 與 `.pyd`。

本機初步測試顯示，x64 Python 的 backend request 約快 13%～18%，但每次 request 僅減少約 0.12～0.16 ms。對完整逐鍵輸入延遲的改善通常難以察覺，因此目前不建議只為效能全面遷移至 x64。

## 現行架構

資料路徑如下：

```text
應用程式
  -> 同架構 PIMETextService.dll
  -> Windows named pipe
  -> PIMELauncher.exe
  -> stdin/stdout
  -> Python backend
```

`PIMETextService.dll` 會載入應用程式內，因此必須提供 x86、x64 與 ARM64 版本。Launcher 與 backend 是獨立程序，透過 named pipe、stdin/stdout 和 UTF-8 JSON 通訊，不要求彼此使用相同位元架構。

目前元件架構如下：

| 元件 | 架構 |
| --- | --- |
| `PIMETextService.dll` | x86、x64、ARM64 |
| `PIMELauncher.exe` | x86 |
| Embedded Python backend | x86 |
| Python 原生 DLL／`.pyd` | x86 |

## x86 證據

`backends.json` 固定啟動 repository 內的 embedded Python：

```json
{
    "name": "python",
    "command": "python\\python3\\python.exe",
    "workingDir": "python",
    "params": "server.py"
}
```

執行 `python/python3/python.exe` 得到：

```text
Python 3.12.9 [MSC v.1942 32 bit (Intel)]
platform.architecture(): 32bit
pointer size: 32
```

PE header 檢查結果：

| 檔案 | PE Machine | 架構 |
| --- | --- | --- |
| `python/python3/python.exe` | `0x014C` | x86 |
| `python/python3/pythonw.exe` | `0x014C` | x86 |
| `python/python3/python312.dll` | `0x014C` | x86 |
| `python/python3/_sqlite3.pyd` | `0x014C` | x86 |
| `python/libchewing/chewing.dll` | `0x014C` | x86 |
| `python/opencc/opencc.dll` | `0x014C` | x86 |
| `python/input_methods/rime/rime.dll` | `0x014C` | x86 |
| `python/python3/Lib/site-packages/tornado/speedups.pyd` | `0x014C` | x86 |

正式 runtime 更新流程同樣指定 x86：

- `.agents/skills/update-runtimes/scripts/update_runtimes.ps1` 下載 `python-<version>-embed-win32.zip`。
- `PIMELauncher/.cargo/config.toml` 的 Rust target 是 `i686-pc-windows-msvc`。
- `CMakeLists.txt` 只在 32-bit build 加入 `PIMELauncher`。
- `installer/installer.nsi` 將共用 runtime 安裝到 `$PROGRAMFILES32\PIME`。

`HACKING.txt` 所稱的「Python 3.5 32-bit」只有位元架構仍正確；目前 checked-in runtime 已是 Python 3.12.9。

## 初步效能測試

測試環境比較 repository 內的 CPython 3.12.9 x86 與同一台電腦上的 CPython 3.12.13 x64。因 patch 版本及封裝方式略有差異，數據只能作為方向性證據。

### JSON microbenchmark

測試資料模擬包含 256 個 `keyStates` 的 PIME keyboard message：

| 測試 | x86 | x64 | x64 改善 |
| --- | ---: | ---: | ---: |
| JSON parse + serialize | 約 57.6 µs | 約 38.6 µs | 約 33% |
| 建立及序列化 reply | 約 4.4 µs | 約 2.8 µs | 約 36% |

雖然比例明顯，單次 request 實際僅節省約 20 µs，也就是 0.02 ms。

### Python backend pipe round-trip

使用純 Python 的 `meow` 輸入法，量測：

```text
stdin -> JSON decode -> onKeyDown -> JSON encode -> stdout flush
```

三輪結果：

| Runtime | 每次 request |
| --- | ---: |
| x86 | 0.915～0.970 ms |
| x64 | 0.791～0.807 ms |

x64 約快 13%～18%，每次 request 減少約 0.12～0.16 ms。此測試未包含 TSF callback、named pipe、Launcher routing 與 UI 更新，因此完整使用者路徑的改善比例預期更小。

### 記憶體取捨

簡單測試顯示 x64 Python 的基礎 working set 與物件大小較大：

| 項目 | x86 | x64 |
| --- | ---: | ---: |
| 空 Python working set | 約 12.2 MB | 約 13.7 MB |
| 空 `dict` | 40 bytes | 64 bytes |
| 空 `list` | 28 bytes | 56 bytes |

x64 可以突破 32-bit address-space 限制，但目前沒有證據顯示 PIME Python backend 接近該限制。

## x64 遷移範圍

不能只替換 `python.exe`。64-bit Python 無法載入 32-bit DLL 或 `.pyd`，因此至少需要：

1. 換成完整的 x64 embedded Python，包括 `python312.dll`、標準庫 `.pyd`、OpenSSL、libffi 與 SQLite DLL。
2. 建置或取得 x64 的 `chewing.dll`、`opencc.dll`、`rime.dll` 與 `tornado/speedups.pyd`。
3. 檢查 installer、簽章、設定工具捷徑、`compileall` 與舊 x86 檔案清理流程。
4. 重新定義 Windows x86、x64、ARM64 的支援政策。

`PIMELauncher.exe` 可以維持 x86，因為 x86 程序可以啟動 x64 child process，現有 stdin/stdout IPC 也不依賴相同位元架構。

## ctypes 相容性風險

現有 bindings 不能直接假定為 x64-safe：

- `python/opencc/__init__.py` 的 `opencc_open()` 未設定 pointer `restype`。
- `python/libchewing/libchewing.py` 的 `chewing_new()` 與 `chewing_new2()` 未設定 pointer `restype`。
- Rime binding 仍需核對所有 `argtypes`、`restype`、structure alignment 與 callback ABI。

ctypes 未設定 `restype` 時預設使用 C `int`。在 x64 Python 中，這可能截斷 64-bit pointer，造成 crash 或記憶體錯誤。

## 建議

目前維持 x86 backend。若目標是降低打字延遲，應先量測完整的 TSF → Launcher → backend 路徑，並優先檢查 IPC 次數、設定檔檢查、磁碟 I/O、SQLite、cinbase 查表與 native input engine。

只有在下列情況之一成立時，x64 遷移才有較充分理由：

- 專案停止支援 32-bit Windows。
- 第三方套件停止提供 x86 build。
- 輸入模型或字典確實接近 x86 記憶體上限。
- 同版本、同編譯設定的完整 benchmark 證明 p95／p99 輸入延遲有實質改善。

遷移前應分別測試 Chewing、Rime 與純 Python cinbase，並比較 cold start、steady-state、p50、p95、p99、working set 及安裝大小。
