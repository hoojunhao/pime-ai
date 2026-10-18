# Builds and stages the pinned libchewing runtime for PIME's x86 Python backend.
# Generated with assistance from OpenAI GPT-5.6.

[CmdletBinding()]
param(
    [string]$BuildDirectory,
    [string]$VcpkgRoot,
    [string]$Generator,
    [switch]$Clean,
    [switch]$RunTests
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$libchewingRoot = Join-Path $repositoryRoot "libchewing"
$runtimeRoot = Join-Path $repositoryRoot "python\libchewing"
$runtimeDataRoot = Join-Path $runtimeRoot "data"
$libchewingPatch = Join-Path $repositoryRoot `
    "patches\libchewing-v0.13.1-sqlite-user-usage.patch"
$pimeDictionarySource = Join-Path $repositoryRoot "data\chewing\pime.csv"
$pimeAiDictionarySource = Join-Path $repositoryRoot "data\chewing\pime-ai.csv"
$dictionaryValidator = Join-Path $repositoryRoot `
    "scripts\validate-chewing-dictionaries.py"
$bundledPython = Join-Path $repositoryRoot "python\python3\python.exe"
$expectedLibchewingCommit = "f071d2e95c531cc39bb4325cd5a5d0e1d51daef8"
$expectedDataCommit = "bfba418ea8a4bd2fe10b9bf80b4bf81ec01af5f4"
$rustToolchain = "1.88.0-x86_64-pc-windows-msvc"
$rustTarget = "i686-pc-windows-msvc"
$vcpkgTriplet = "x86-windows-static"

if (-not $BuildDirectory) {
    $BuildDirectory = Join-Path $repositoryRoot "build\libchewing-x86"
} elseif (-not [IO.Path]::IsPathRooted($BuildDirectory)) {
    $BuildDirectory = Join-Path $repositoryRoot $BuildDirectory
}

function Invoke-NativeCommand {
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,
        [Parameter(ValueFromRemainingArguments)]
        [string[]]$Arguments
    )

    & $FilePath @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$FilePath exited with code $LASTEXITCODE"
    }
}

function Get-GitRevision {
    param([Parameter(Mandatory)][string]$Path)

    $revision = & git -C $Path rev-parse HEAD
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to read the git revision for $Path"
    }
    return $revision.Trim()
}

function Get-VisualStudioInstallation {
    $vswhere = Join-Path ${env:ProgramFiles(x86)} `
        "Microsoft Visual Studio\Installer\vswhere.exe"
    if (-not (Test-Path $vswhere)) {
        throw "Visual Studio Installer's vswhere.exe was not found."
    }

    $json = & $vswhere -latest -products * -format json
    if ($LASTEXITCODE -ne 0) {
        throw "vswhere.exe failed with code $LASTEXITCODE"
    }

    $installation = @($json | ConvertFrom-Json)
    if ($installation.Count -ne 1) {
        throw "A supported Visual Studio installation was not found."
    }
    return $installation[0]
}

function Get-PeMachine {
    param([Parameter(Mandatory)][string]$Path)

    $bytes = [IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -lt 64 -or $bytes[0] -ne 0x4d -or $bytes[1] -ne 0x5a) {
        throw "$Path is not a PE file."
    }

    $peOffset = [BitConverter]::ToInt32($bytes, 0x3c)
    if ($peOffset -lt 0 -or $peOffset + 6 -gt $bytes.Length) {
        throw "$Path has an invalid PE header offset."
    }
    if ($bytes[$peOffset] -ne 0x50 -or
        $bytes[$peOffset + 1] -ne 0x45 -or
        $bytes[$peOffset + 2] -ne 0 -or
        $bytes[$peOffset + 3] -ne 0) {
        throw "$Path has an invalid PE signature."
    }

    return [BitConverter]::ToUInt16($bytes, $peOffset + 4)
}

function Get-RepositoryRelativePath {
    param([Parameter(Mandatory)][string]$Path)

    $fullRoot = [IO.Path]::GetFullPath($repositoryRoot)
    $fullPath = [IO.Path]::GetFullPath($Path)
    if (-not $fullPath.StartsWith(
        $fullRoot,
        [StringComparison]::OrdinalIgnoreCase
    )) {
        throw "$fullPath is outside the repository."
    }

    $trimCharacters = [char[]]@(
        [IO.Path]::DirectorySeparatorChar,
        [IO.Path]::AltDirectorySeparatorChar
    )
    return $fullPath.Substring($fullRoot.Length).TrimStart($trimCharacters)
}

if (-not (Test-Path (Join-Path $libchewingRoot "CMakeLists.txt"))) {
    throw "libchewing is not initialized. Run: git submodule update --init --recursive"
}
if (-not (Test-Path $bundledPython)) {
    throw "Bundled Python was not found at $bundledPython"
}
if (-not (Test-Path $libchewingPatch)) {
    throw "Required libchewing patch was not found at $libchewingPatch"
}

$libchewingCommit = Get-GitRevision $libchewingRoot
$dataRoot = Join-Path $libchewingRoot "data"
$dataCommit = Get-GitRevision $dataRoot
if ($libchewingCommit -ne $expectedLibchewingCommit) {
    throw "Unexpected libchewing revision: $libchewingCommit"
}
if ($dataCommit -ne $expectedDataCommit) {
    throw "Unexpected libchewing-data revision: $dataCommit"
}
$sourceChanges = @(
    & git -C $libchewingRoot status --porcelain --untracked-files=no
)
if ($LASTEXITCODE -ne 0) {
    throw "Unable to inspect the libchewing worktree."
}
if ($sourceChanges.Count -ne 0) {
    throw "The libchewing submodule must be clean before building."
}
$libchewingPatchHash = (
    Get-FileHash -Algorithm SHA256 $libchewingPatch
).Hash.ToLowerInvariant()

Invoke-NativeCommand $bundledPython $dictionaryValidator `
    --base (Join-Path $dataRoot "dict\chewing\word.csv") `
    --base (Join-Path $dataRoot "dict\chewing\tsi.csv") `
    --overlay $pimeDictionarySource `
    --overlay $pimeAiDictionarySource

$cmakeVersionLine = (& cmake --version | Select-Object -First 1)
if ($LASTEXITCODE -ne 0 -or $cmakeVersionLine -notmatch "(\d+\.\d+\.\d+)") {
    throw "Unable to determine the CMake version."
}
if ([Version]$Matches[1] -lt [Version]"3.27.0") {
    throw "libchewing v0.13.1 requires CMake 3.27 or newer."
}

$installedRustToolchains = @(& rustup toolchain list)
if ($LASTEXITCODE -ne 0) {
    throw "Unable to query installed Rust toolchains."
}
if (-not ($installedRustToolchains -match "^$([regex]::Escape($rustToolchain))")) {
    throw "Missing Rust toolchain $rustToolchain."
}
$installedRustTargets = @(
    & rustup target list --installed --toolchain $rustToolchain
)
if ($LASTEXITCODE -ne 0 -or $rustTarget -notin $installedRustTargets) {
    throw "Missing Rust target $rustTarget for $rustToolchain."
}
$env:RUSTUP_TOOLCHAIN = $rustToolchain

$visualStudio = Get-VisualStudioInstallation
$visualStudioMajor = [int]($visualStudio.installationVersion.Split(".")[0])
if (-not $Generator) {
    $Generator = switch ($visualStudioMajor) {
        17 { "Visual Studio 17 2022" }
        18 { "Visual Studio 18 2026" }
        default {
            throw "Unsupported Visual Studio major version: $visualStudioMajor"
        }
    }
}

if (-not $VcpkgRoot) {
    if ($env:VCPKG_ROOT) {
        $VcpkgRoot = $env:VCPKG_ROOT
    } else {
        $VcpkgRoot = Join-Path $visualStudio.installationPath "VC\vcpkg"
    }
}
$vcpkgToolchain = Join-Path $VcpkgRoot "scripts\buildsystems\vcpkg.cmake"
if (-not (Test-Path $vcpkgToolchain)) {
    throw "vcpkg toolchain was not found at $vcpkgToolchain"
}
$vcpkgInstalledRoot = Join-Path $BuildDirectory "vcpkg_installed"
$sqliteRoot = Join-Path $vcpkgInstalledRoot $vcpkgTriplet
$sqliteLibrary = Join-Path $sqliteRoot "lib\sqlite3.lib"
$sqliteInclude = Join-Path $sqliteRoot "include"
$env:VCPKGRS_TRIPLET = $vcpkgTriplet
$env:SQLITE3_LIB_DIR = Split-Path -Parent $sqliteLibrary
$env:SQLITE3_INCLUDE_DIR = $sqliteInclude
$env:SQLITE3_STATIC = "1"

if ($Clean -and (Test-Path $BuildDirectory)) {
    Remove-Item -Recurse -Force $BuildDirectory
}

$patchApplied = $false
try {
Invoke-NativeCommand git -C $libchewingRoot apply --unidiff-zero --check `
    $libchewingPatch
Invoke-NativeCommand git -C $libchewingRoot apply --unidiff-zero `
    $libchewingPatch
$patchApplied = $true

$installRoot = Join-Path $BuildDirectory "install"
$buildTesting = if ($RunTests) { "ON" } else { "OFF" }
$configureArguments = @(
    "-S", $libchewingRoot,
    "-B", $BuildDirectory,
    "-G", $Generator,
    "-A", "Win32",
    "-DCMAKE_TOOLCHAIN_FILE=$vcpkgToolchain",
    "-DVCPKG_MANIFEST_DIR=$repositoryRoot",
    "-DVCPKG_TARGET_TRIPLET=$vcpkgTriplet",
    "-DVCPKG_INSTALLED_DIR=$vcpkgInstalledRoot",
    "-DRust_CARGO_TARGET=$rustTarget",
    "-DSQLite3_LIBRARY=$sqliteLibrary",
    "-DSQLite3_INCLUDE_DIR=$sqliteInclude",
    "-DCMAKE_INSTALL_PREFIX=$installRoot",
    "-DBUILD_SHARED_LIBS=ON",
    "-DBUILD_DATA=ON",
    "-DBUILD_DOC=OFF",
    "-DBUILD_TESTING=$buildTesting",
    "-DWITH_SQLITE3=ON",
    "-DUSE_SYSTEM_CHEWING_CLI=OFF"
)
Invoke-NativeCommand cmake @configureArguments
Invoke-NativeCommand cmake --build $BuildDirectory --config Release --parallel

if ($RunTests) {
    $testPath = @(
        (Join-Path $BuildDirectory "Release"),
        $BuildDirectory,
        $env:PATH
    ) -join [IO.Path]::PathSeparator
    $env:PATH = $testPath
    foreach ($testName in @(
        "test-bopomofo",
        "test-config",
        "test-easy-symbol",
        "test-error-handling",
        "test-fullshape",
        "test-keyboard",
        "test-keyboardless",
        "test-logger",
        "test-regression",
        "test-reset",
        "test-special-symbol",
        "test-struct-size",
        "test-symbol",
        "test-userphrase"
    )) {
        Invoke-NativeCommand (Join-Path $BuildDirectory "tests\$testName.exe")
    }

    $env:CARGO_TARGET_DIR = Join-Path $BuildDirectory "cargo-tests"
    Push-Location $libchewingRoot
    try {
        Invoke-NativeCommand cargo test --locked --target $rustTarget `
            --features sqlite
        Invoke-NativeCommand cargo test --locked --target $rustTarget `
            -p chewing_capi --features sqlite
        Invoke-NativeCommand cargo test --locked --target $rustTarget `
            -p chewing-cli
    } finally {
        Pop-Location
    }
}

Remove-Item -Recurse -Force $installRoot -ErrorAction SilentlyContinue
Invoke-NativeCommand cmake --install $BuildDirectory --config Release `
    --prefix $installRoot

$sourceFiles = [ordered]@{
    "chewing.dll" = Join-Path $installRoot "bin\chewing-msvc.dll"
    "chewing-cli.exe" = Join-Path $installRoot "bin\chewing-cli.exe"
    "word.dat" = Join-Path $installRoot "share\libchewing\word.dat"
    "tsi.dat" = Join-Path $installRoot "share\libchewing\tsi.dat"
    "symbols.dat" = Join-Path $installRoot "share\libchewing\symbols.dat"
    "swkb.dat" = Join-Path $installRoot "share\libchewing\swkb.dat"
}
foreach ($entry in $sourceFiles.GetEnumerator()) {
    if (-not (Test-Path $entry.Value)) {
        throw "Missing build artifact: $($entry.Value)"
    }
}

$machine = Get-PeMachine $sourceFiles["chewing.dll"]
if ($machine -ne 0x014c) {
    throw ("chewing.dll is not x86. PE Machine: 0x{0:x4}" -f $machine)
}

$stagingRoot = Join-Path $BuildDirectory "pime-runtime"
$stagingDataRoot = Join-Path $stagingRoot "data"
$stagingDictionaryRoot = Join-Path $stagingDataRoot "dictionary.d"
Remove-Item -Recurse -Force $stagingRoot -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force $stagingDataRoot | Out-Null
New-Item -ItemType Directory -Force $stagingDictionaryRoot | Out-Null
Copy-Item $sourceFiles["chewing.dll"] (Join-Path $stagingRoot "chewing.dll")
foreach ($name in "word.dat", "tsi.dat", "symbols.dat", "swkb.dat") {
    Copy-Item $sourceFiles[$name] (Join-Path $stagingDataRoot $name)
}
Invoke-NativeCommand $sourceFiles["chewing-cli.exe"] init-database --csv `
    --usage extension $pimeDictionarySource `
    (Join-Path $stagingDictionaryRoot "pime.dat")
Invoke-NativeCommand $sourceFiles["chewing-cli.exe"] init-database --csv `
    --usage extension $pimeAiDictionarySource `
    (Join-Path $stagingDictionaryRoot "pime-ai.dat")

New-Item -ItemType Directory -Force $runtimeDataRoot | Out-Null
Copy-Item (Join-Path $stagingRoot "chewing.dll") `
    (Join-Path $runtimeRoot "chewing.dll") -Force
foreach ($name in "word.dat", "tsi.dat", "symbols.dat", "swkb.dat") {
    Copy-Item (Join-Path $stagingDataRoot $name) `
        (Join-Path $runtimeDataRoot $name) -Force
}
$runtimeDictionaryRoot = Join-Path $runtimeDataRoot "dictionary.d"
Remove-Item -Recurse -Force $runtimeDictionaryRoot -ErrorAction SilentlyContinue
Copy-Item $stagingDictionaryRoot $runtimeDictionaryRoot -Recurse
foreach ($obsoleteName in "dictionary.dat", "index_tree.dat", "pinyin.tab") {
    Remove-Item (Join-Path $runtimeDataRoot $obsoleteName) `
        -Force -ErrorAction SilentlyContinue
}

$manifestLines = @(
    "libchewing=$libchewingCommit"
    "libchewing-data=$dataCommit"
    "libchewing-patch-sha256=$libchewingPatchHash"
    "rust-toolchain=$rustToolchain"
    "rust-target=$rustTarget"
    "vcpkg-triplet=$vcpkgTriplet"
    ("pe-machine=0x{0:x4}" -f $machine)
)
foreach ($path in @(
    (Join-Path $runtimeRoot "chewing.dll"),
    (Join-Path $runtimeDataRoot "word.dat"),
    (Join-Path $runtimeDataRoot "tsi.dat"),
    (Join-Path $runtimeDataRoot "symbols.dat"),
    (Join-Path $runtimeDataRoot "swkb.dat")
    (Join-Path $runtimeDataRoot "dictionary.d\pime.dat")
    (Join-Path $runtimeDataRoot "dictionary.d\pime-ai.dat")
)) {
    $hash = Get-FileHash -Algorithm SHA256 $path
    $relativePath = Get-RepositoryRelativePath $path
    $manifestLines += "$relativePath=$($hash.Hash.ToLowerInvariant())"
}
$manifestPath = Join-Path $BuildDirectory "pime-runtime-manifest.txt"
[IO.File]::WriteAllLines($manifestPath, $manifestLines)

Write-Host "libchewing v0.13.1 runtime staged successfully."
Write-Host "Manifest: $manifestPath"
} finally {
    if ($patchApplied) {
        & git -C $libchewingRoot apply --unidiff-zero --reverse `
            $libchewingPatch
        if ($LASTEXITCODE -ne 0) {
            throw "Unable to remove the carried libchewing patch."
        }
    }
    $changedSourceFiles = @(
        & git -C $libchewingRoot diff --name-only
    )
    if ($LASTEXITCODE -eq 0 -and "Cargo.lock" -in $changedSourceFiles) {
        & git -C $libchewingRoot checkout -- Cargo.lock
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Unable to restore libchewing/Cargo.lock."
        }
    }
    $remainingSourceChanges = @(
        & git -C $libchewingRoot status --porcelain --untracked-files=no
    )
    if ($LASTEXITCODE -ne 0 -or $remainingSourceChanges.Count -ne 0) {
        throw "The libchewing submodule is not clean after building."
    }
}
