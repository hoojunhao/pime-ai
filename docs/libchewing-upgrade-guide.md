<!-- Generated with assistance from OpenAI GPT-5.6. -->

# libchewing 升級指南

## 維護模型

`libchewing/` 是固定 commit 的 Git submodule，來源為
`https://codeberg.org/chewing/libchewing.git`。`libchewing/data/` 是其
巢狀 submodule。PIME AI 不自動追蹤上游分支；升級必須明確選定穩定版、
更新父專案的 submodule pointer，並重新驗證 x86 runtime。

PIME AI 的 libchewing 修正保存在 `patches/`，不直接留在 submodule：

- `libchewing-v*-sqlite-user-usage.patch`：修正 SQLite 使用者詞庫 usage。
- `libchewing-v*-promote-selected-phrase.patch`：提交低頻候選時，將其提升至
  相同讀音最高頻率加 10。

`scripts/build-libchewing.ps1` 會暫時套用 patches、建置及測試，最後反向
移除 patches 並確認 submodule 乾淨。建置 manifest 會記錄 submodule
commits、patch hashes、工具鏈及 runtime hashes。

## 升級流程

### 1. 建立獨立分支

```powershell
git switch -c chore/update-libchewing-vX.Y.Z
git -C libchewing fetch origin --tags
git -C libchewing tag --list
```

選定穩定版後更新 submodule 及其巢狀依賴：

```powershell
git -C libchewing checkout vX.Y.Z
git -C libchewing submodule update --init --recursive
git -C libchewing rev-parse HEAD
git -C libchewing/data rev-parse HEAD
```

不要使用 `git submodule update --remote` 追蹤未固定的遠端分支。

### 2. 更新建置鎖定值

在 `scripts/build-libchewing.ps1` 更新：

- `$expectedLibchewingCommit`
- `$expectedDataCommit`
- `$rustToolchain`，僅限新版確實變更需求時
- `$libchewingPatches` 中的版本化 patch 路徑

保持 PIME Python backend 使用 `i686-pc-windows-msvc`；產出的
`chewing.dll` PE Machine 必須為 `0x014c`。

### 3. 檢查 carried patches

先確認上游是否已提供等效修正。若已修正，移除對應 carried patch，但保留
PIME 的回歸測試。

若仍需 patch，先檢查能否乾淨套用：

```powershell
git -C libchewing apply --check `
    ..\patches\libchewing-vX.Y.Z-promote-selected-phrase.patch
```

若檢查失敗，不可強制套用。重新檢查新版的
`src/editor/estimate.rs`、`src/editor/mod.rs`、詞頻尺度與 auto-learn
流程，再針對新版本製作最小 patch。

學習排序必須保留此可觀察行為：

1. 遷移含舊詞頻的 `userphrase_v1`。
2. 第一次輸入 `ㄋㄧˇ` 預設為「你」。
3. 選擇「妳」並 Enter。
4. 關閉並重新建立 context。
5. 再輸入 `ㄋㄧˇ` 時預設為「妳」。

### 4. 建置及測試

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
    -File .\scripts\build-libchewing.ps1 `
    -Clean `
    -RunTests

$env:PYTHONDONTWRITEBYTECODE = "1"
.\python\python3\python.exe .\tests\test_libchewing_binding.py
```

至少確認：

- native、Rust core、C API 與 `chewing-cli` tests 全部通過。
- `test_selected_migrated_candidate_becomes_next_default` 通過。
- `python/libchewing/chewing.dll` 是 x86。
- `git -C libchewing status --short` 沒有輸出。
- `build/libchewing-x86/pime-runtime-manifest.txt` 記錄新 commits 與 patches。
- 完整 `build.bat`、installer payload 及 Windows 10 實機輸入通過。

### 5. 更新文件及提交

同步更新：

- `README.md`
- 版本對應的 migration plan
- patch 檔名及 `scripts/build-libchewing.ps1`
- tracked runtime：`python/libchewing/chewing.dll` 與必要資料檔

依序拆分 submodule pointer、patch、build pipeline、runtime、測試與文件；
檔案 rename 應使用獨立 commit。不要混入無關功能或修正。

## 上游與回復策略

優先將通用修正提交給 libchewing 上游。上游正式版本納入後，PIME AI 應移除
重複 patch，但持續執行 migration 與 rerank 回歸測試。

升級失敗時回復整組 libchewing pointer、DLL、系統詞庫與 Python integration，
不可只降級 DLL。使用者資料 migration 前必須保留並驗證
`chewing.sqlite3.pre-v0.13.1.bak`。
