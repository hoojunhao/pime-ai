# Generates the single installer license document from the authoritative files.
# Generated with assistance from OpenAI GPT-5.6.

[CmdletBinding()]
param(
    [switch]$Check
)

$ErrorActionPreference = "Stop"
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$outputPath = Join-Path $PSScriptRoot "PIME-Licenses.txt"
$crateLicensePath = Join-Path $PSScriptRoot `
    "libchewing-crate-licenses.txt"
$crateLicenseGenerator = Join-Path $PSScriptRoot `
    "generate-libchewing-crate-licenses.py"
$python = Join-Path $repositoryRoot "python\python3\python.exe"
$separator = "=" * 78

if ($Check) {
    & $python $crateLicenseGenerator --check $crateLicensePath
} else {
    & $python $crateLicenseGenerator $crateLicensePath
}
if ($LASTEXITCODE -ne 0) {
    throw "Unable to generate libchewing crate licenses."
}

$content = @(
    "PIME - GNU Lesser General Public License"
    $separator
    ""
    [IO.File]::ReadAllText((Join-Path $repositoryRoot "LGPL-2.0.txt")).TrimEnd()
    ""
    ""
    "libchewing and libchewing-data - GNU LGPL 2.1 or later"
    $separator
    ""
    "libchewing-data dictionary metadata identifies its license as LGPL-2.1-or-later."
    "Pinned revisions are documented in docs/libchewing-v0.13.1-migration-plan.md."
    ""
    [IO.File]::ReadAllText((Join-Path $repositoryRoot "libchewing\COPYING")).TrimEnd()
    ""
    ""
    "SQLite"
    $separator
    ""
    "SQLite is in the Public Domain."
    "https://www.sqlite.org/copyright.html"
    ""
    ""
    [IO.File]::ReadAllText($crateLicensePath).TrimEnd()
    ""
    ""
    "Bundled Python Runtime Licenses"
    $separator
    ""
    [IO.File]::ReadAllText((Join-Path $repositoryRoot "python\python3\LICENSE.txt")).TrimEnd()
    ""
) -join "`r`n"

if ($Check) {
    if (-not (Test-Path $outputPath)) {
        throw "Missing generated license file: $outputPath"
    }

    $existing = [IO.File]::ReadAllText($outputPath)
    if ($existing -cne $content) {
        throw "PIME-Licenses.txt is stale. Run installer/generate-licenses.ps1."
    }

    return
}

$utf8Bom = New-Object Text.UTF8Encoding($true)
[IO.File]::WriteAllText($outputPath, $content, $utf8Bom)
