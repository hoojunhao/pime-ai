# Generates the single installer license document from the authoritative files.
# Generated with assistance from OpenAI GPT-5.6.

[CmdletBinding()]
param(
    [switch]$Check
)

$ErrorActionPreference = "Stop"
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$outputPath = Join-Path $PSScriptRoot "PIME-Licenses.txt"
$separator = "=" * 78

$content = @(
    "PIME - GNU Lesser General Public License"
    $separator
    ""
    [IO.File]::ReadAllText((Join-Path $repositoryRoot "LGPL-2.0.txt")).TrimEnd()
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
