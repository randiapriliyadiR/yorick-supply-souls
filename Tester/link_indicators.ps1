<#
.SYNOPSIS
  Hardlink project Indicators (+ Include) into MT5 search paths.
  MT5 iCustom does not reliably follow directory junctions; hardlinks keep one source of truth.
#>
$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$Mql5 = Split-Path -Parent (Split-Path -Parent $ProjectRoot)
if (-not (Test-Path (Join-Path $Mql5 "Indicators"))) {
  throw "Expected MQL5 root above Experts project. Got: $Mql5"
}

$IndSrc = Join-Path $ProjectRoot "Indicators"
$IndDst = Join-Path $Mql5 "Indicators"
$IncSrc = Join-Path $ProjectRoot "Include\YorickSoS"
$IncDst = Join-Path $Mql5 "Include\YorickSoS"

# Drop old junction layout if present
$oldJunc = Join-Path $IndDst "yorick-supply-souls"
if (Test-Path $oldJunc) {
  $item = Get-Item $oldJunc -Force
  if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
    cmd /c "rmdir `"$oldJunc`"" | Out-Null
  }
}

function Ensure-Hardlink([string]$link, [string]$target) {
  if (-not (Test-Path -LiteralPath $target)) { throw "Missing: $target" }
  if (Test-Path -LiteralPath $link) { Remove-Item -LiteralPath $link -Force }
  cmd /c "mklink /H `"$link`" `"$target`"" | Out-Null
  if (-not (Test-Path -LiteralPath $link)) { throw "Hardlink failed: $link" }
}

foreach ($name in @("Yorick Structure", "Yorick FVG", "Yorick Zones")) {
  Ensure-Hardlink (Join-Path $IndDst "$name.mq5") (Join-Path $IndSrc "$name.mq5")
  $ex5 = Join-Path $IndSrc "$name.ex5"
  if (Test-Path -LiteralPath $ex5) {
    Ensure-Hardlink (Join-Path $IndDst "$name.ex5") $ex5
  }
}

if (Test-Path $IncDst) {
  $incItem = Get-Item $IncDst -Force
  if ($incItem.Attributes -band [IO.FileAttributes]::ReparsePoint) {
    # already a junction to project — ok
  } else {
    Remove-Item $IncDst -Recurse -Force
    cmd /c "mklink /J `"$IncDst`" `"$IncSrc`"" | Out-Null
  }
} else {
  New-Item -ItemType Directory -Force -Path (Split-Path $IncDst) | Out-Null
  cmd /c "mklink /J `"$IncDst`" `"$IncSrc`"" | Out-Null
}

Write-Host "Linked indicators into $IndDst (hardlinks) and Include\YorickSoS (junction)."
Write-Host "After MetaEditor recompiles an indicator .ex5, re-run this script if MT5 cannot load it."
