<#
.SYNOPSIS
  Compile Yorick Supply of Souls (+ indicators) and run headless MT5 Strategy Tester.
#>
param(
  [string]$Symbol = "XAUUSD",
  [string]$Period = "M5",
  [string]$TrendTF = "H4",
  [string]$ZoneTFs = "M15,M5",
  [string]$OnePosPerTf = "false",
  [string]$FromDate = "2021.01.01",
  [string]$ToDate = "2026.08.26",
  [int]$Deposit = 100000,
  [int]$Model = 1,
  [int]$Leverage = 500,
  [int]$TimeoutSec = 3600,
  [string]$ReportName = "YorickSoS_XAUUSD_M5_100k",
  [double]$RiskPct = 2.0,
  [string]$QualityMode = "0",
  [double]$RiskMinPct = 0.5,
  [double]$RiskMaxPct = 2.0,
  [int]$AtrPeriod = 14,
  [double]$ImpulseAtrMult = 1.25,
  [double]$BodyAtrMult = 0.65,
  [int]$SwingStrength = 3,
  [string]$RequireBos = "true",
  [string]$RequireFvg = "true",
  [string]$RequireSlow = "false",
  [double]$SlowMaxAtr = 0.7,
  [double]$SharpAtr = 1.2,
  [int]$MinApproachBars = 2,
  [double]$SlZoneMult = 2.5,
  [string]$UseGuard = "true",
  [string]$RequireTrend = "false",
  [string]$TrendOnZoneTf = "false",
  [string]$RequireMinRr = "false",
  [double]$MinRiskReward = 2.5,
  [string]$UseAtrRegime = "true",
  [int]$AtrRegimeBars = 50,
  [double]$AtrRegimeMult = 1.5,
  [double]$BeTriggerR = 1.0,
  [double]$TrailStartR = 1.0,
  [double]$TrailDistR = 1.0,
  [string]$SimCommission = "false",
  [double]$CommissionPerLot = 3.5,
  [switch]$SkipCompile
)

$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$TerminalData = "C:\Users\randi\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075"
$Mql5 = Join-Path $TerminalData "MQL5"
$TerminalExe = "C:\Program Files\MetaTrader 5\terminal64.exe"
$MetaEditor = "C:\Program Files\MetaTrader 5\metaeditor64.exe"
$EaMq5 = Join-Path $ProjectRoot "Yorick Supply of Souls.mq5"
$IncSrc = Join-Path $ProjectRoot "Include\YorickSoS"
$IncDst = Join-Path $Mql5 "Include\YorickSoS"
$IndSrcDir = Join-Path $ProjectRoot "Indicators"
$IndDstDir = Join-Path $Mql5 "Indicators"
$IniTemplate = Join-Path $PSScriptRoot "yorick_sos.ini"
$IniRun = Join-Path $PSScriptRoot ("_run_{0}.ini" -f $ReportName)
$SummaryOut = Join-Path $PSScriptRoot ("last_summary_{0}.txt" -f $ReportName)

if (-not (Test-Path $TerminalExe)) { throw "terminal64.exe not found: $TerminalExe" }
if (-not (Test-Path $EaMq5)) { throw "EA source not found: $EaMq5" }

# Hardlink indicators into MQL5/Indicators (junctions break iCustom in MT5)
& (Join-Path $PSScriptRoot "link_indicators.ps1")
$IndDstDir = Join-Path $Mql5 "Indicators"

function Compile-Mq5([string]$src, [string]$logName) {
  $compileLog = Join-Path $ProjectRoot $logName
  $compileArgs = @("/compile:`"$src`"", "/include:`"$Mql5`"", "/log:`"$compileLog`"")
  Start-Process -FilePath $MetaEditor -ArgumentList $compileArgs -Wait -PassThru | Out-Null
  Start-Sleep -Seconds 2
  if (-not (Test-Path $compileLog)) { throw "Compile log missing: $compileLog" }
  $logText = [System.Text.Encoding]::Unicode.GetString([System.IO.File]::ReadAllBytes($compileLog))
  $compileResult = ($logText -split "`r?`n" | Where-Object { $_ -match "Result:" } | Select-Object -Last 1)
  Write-Host $compileResult
  if ($compileResult -notmatch "0 errors") {
    throw "Compile failed for $src. See $compileLog"
  }
}

if (-not $SkipCompile) {
  Write-Host "== Compile indicators + EA =="
  Compile-Mq5 (Join-Path $IndDstDir "Yorick Structure.mq5") "compile_st.log"
  Compile-Mq5 (Join-Path $IndDstDir "Yorick FVG.mq5") "compile_fvg.log"
  Compile-Mq5 (Join-Path $IndDstDir "Yorick Zones.mq5") "compile_zn.log"
  Compile-Mq5 $EaMq5 "compile.log"
} else {
  Write-Host "== Skip compile =="
}

$ini = Get-Content $IniTemplate -Raw
$ini = $ini -replace "(?m)^Symbol=.*$", "Symbol=$Symbol"
$ini = $ini -replace "(?m)^Period=.*$", "Period=$Period"
$ini = $ini -replace "(?m)^FromDate=.*$", "FromDate=$FromDate"
$ini = $ini -replace "(?m)^ToDate=.*$", "ToDate=$ToDate"
$ini = $ini -replace "(?m)^Deposit=.*$", "Deposit=$Deposit"
$ini = $ini -replace "(?m)^Model=.*$", "Model=$Model"
$ini = $ini -replace "(?m)^Leverage=.*$", "Leverage=$Leverage"
$ini = $ini -replace "(?m)^Report=.*$", "Report=$ReportName"
$ini = $ini -replace "(?m)^InpSymbol=.*$", "InpSymbol=$Symbol"

$tfMap = @{
  "M1" = 1; "M2" = 2; "M3" = 3; "M4" = 4; "M5" = 5; "M6" = 6
  "M10" = 10; "M12" = 12; "M15" = 15; "M20" = 20; "M30" = 30
  "H1" = 16385; "H2" = 16386; "H3" = 16387; "H4" = 16388
  "H6" = 16390; "H8" = 16392; "H12" = 16396
  "D1" = 16408; "W1" = 32769; "MN1" = 49153
}
$tfKey = $Period.ToUpperInvariant()
if (-not $tfMap.ContainsKey($tfKey)) {
  throw "Unsupported Period='$Period'. Use one of: $($tfMap.Keys -join ', ')"
}
$ini = $ini -replace "(?m)^InpTF=.*$", "InpTF=$($tfMap[$tfKey])"
$trendKey = $TrendTF.ToUpperInvariant()
if (-not $tfMap.ContainsKey($trendKey)) { throw "Unsupported TrendTF='$TrendTF'" }
if ($ini -match "(?m)^InpTrendTF=") {
  $ini = $ini -replace "(?m)^InpTrendTF=.*$", "InpTrendTF=$($tfMap[$trendKey])"
} else {
  $ini = $ini -replace "(?m)^InpTF=.*$", "InpTF=$($tfMap[$tfKey])`r`nInpTrendTF=$($tfMap[$trendKey])"
}
$zoneTfIni = $ZoneTFs
if ($ini -match "(?m)^InpZoneTFs=") {
  $ini = $ini -replace "(?m)^InpZoneTFs=.*$", "InpZoneTFs=$zoneTfIni"
} else {
  $ini = $ini.TrimEnd() + "`r`nInpZoneTFs=$zoneTfIni`r`n"
}
if ($ini -match "(?m)^InpOnePosPerTf=") {
  $ini = $ini -replace "(?m)^InpOnePosPerTf=.*$", "InpOnePosPerTf=$OnePosPerTf"
} else {
  $ini = $ini.TrimEnd() + "`r`nInpOnePosPerTf=$OnePosPerTf`r`n"
}
$inv = [System.Globalization.CultureInfo]::InvariantCulture
$riskStr = $RiskPct.ToString($inv)
$riskMinStr = $RiskMinPct.ToString($inv)
$riskMaxStr = $RiskMaxPct.ToString($inv)
$impStr = $ImpulseAtrMult.ToString($inv)
$bodyStr = $BodyAtrMult.ToString($inv)
$slowStr = $SlowMaxAtr.ToString($inv)
$sharpStr = $SharpAtr.ToString($inv)
$slStr = $SlZoneMult.ToString($inv)
$beStr = $BeTriggerR.ToString($inv)
$tsStr = $TrailStartR.ToString($inv)
$tdStr = $TrailDistR.ToString($inv)
$rrStr = $MinRiskReward.ToString($inv)
$atrRegMultStr = $AtrRegimeMult.ToString($inv)
$ini = $ini -replace "(?m)^InpRiskPct=.*$", "InpRiskPct=$riskStr"
# Map aliases: false/true/A/C/off/0/1/2 → enum int
$qMode = $QualityMode.Trim().ToLowerInvariant()
switch ($qMode) {
  { $_ -in @("0","off","false","no") } { $qMode = "0" }
  { $_ -in @("1","a","true","yes") } { $qMode = "1" }
  { $_ -in @("2","c") } { $qMode = "2" }
  default { if ($qMode -notmatch '^[012]$') { throw "QualityMode must be 0/1/2 or off/A/C (got '$QualityMode')" } }
}
if ($ini -match "(?m)^InpQualityMode=") {
  $ini = $ini -replace "(?m)^InpQualityMode=.*$", "InpQualityMode=$qMode"
} elseif ($ini -match "(?m)^InpUseQualityRisk=") {
  $ini = $ini -replace "(?m)^InpUseQualityRisk=.*$", "InpQualityMode=$qMode"
} else {
  $ini = $ini.TrimEnd() + "`r`nInpQualityMode=$qMode`r`n"
}
if ($ini -match "(?m)^InpRiskMinPct=") {
  $ini = $ini -replace "(?m)^InpRiskMinPct=.*$", "InpRiskMinPct=$riskMinStr"
  $ini = $ini -replace "(?m)^InpRiskMaxPct=.*$", "InpRiskMaxPct=$riskMaxStr"
} else {
  $ini = $ini.TrimEnd() + "`r`nInpRiskMinPct=$riskMinStr`r`nInpRiskMaxPct=$riskMaxStr`r`n"
}
$ini = $ini -replace "(?m)^InpAtrPeriod=.*$", "InpAtrPeriod=$AtrPeriod"
$ini = $ini -replace "(?m)^InpImpulseAtrMult=.*$", "InpImpulseAtrMult=$impStr"
$ini = $ini -replace "(?m)^InpBodyAtrMult=.*$", "InpBodyAtrMult=$bodyStr"
$ini = $ini -replace "(?m)^InpSwingStrength=.*$", "InpSwingStrength=$SwingStrength"
$ini = $ini -replace "(?m)^InpRequireBos=.*$", "InpRequireBos=$RequireBos"
$ini = $ini -replace "(?m)^InpRequireFvg=.*$", "InpRequireFvg=$RequireFvg"
$ini = $ini -replace "(?m)^InpRequireSlow=.*$", "InpRequireSlow=$RequireSlow"
$ini = $ini -replace "(?m)^InpSlowMaxAtr=.*$", "InpSlowMaxAtr=$slowStr"
$ini = $ini -replace "(?m)^InpSharpAtr=.*$", "InpSharpAtr=$sharpStr"
$ini = $ini -replace "(?m)^InpMinApproachBars=.*$", "InpMinApproachBars=$MinApproachBars"
$ini = $ini -replace "(?m)^InpSlZoneMult=.*$", "InpSlZoneMult=$slStr"
if ($ini -match "(?m)^InpUseGuard=") {
  $ini = $ini -replace "(?m)^InpUseGuard=.*$", "InpUseGuard=$UseGuard"
  $ini = $ini -replace "(?m)^InpBeTriggerR=.*$", "InpBeTriggerR=$beStr"
  $ini = $ini -replace "(?m)^InpTrailStartR=.*$", "InpTrailStartR=$tsStr"
  $ini = $ini -replace "(?m)^InpTrailDistR=.*$", "InpTrailDistR=$tdStr"
} else {
  $ini = $ini.TrimEnd() + "`r`nInpUseGuard=$UseGuard`r`nInpBeTriggerR=$beStr`r`nInpTrailStartR=$tsStr`r`nInpTrailDistR=$tdStr`r`n"
}
if ($ini -match "(?m)^InpRequireTrend=") {
  $ini = $ini -replace "(?m)^InpRequireTrend=.*$", "InpRequireTrend=$RequireTrend"
  $ini = $ini -replace "(?m)^InpRequireMinRr=.*$", "InpRequireMinRr=$RequireMinRr"
  $ini = $ini -replace "(?m)^InpMinRiskReward=.*$", "InpMinRiskReward=$rrStr"
} else {
  $ini = $ini.TrimEnd() + "`r`nInpRequireTrend=$RequireTrend`r`nInpRequireMinRr=$RequireMinRr`r`nInpMinRiskReward=$rrStr`r`n"
}
if ($ini -match "(?m)^InpUseAtrRegime=") {
  $ini = $ini -replace "(?m)^InpUseAtrRegime=.*$", "InpUseAtrRegime=$UseAtrRegime"
  $ini = $ini -replace "(?m)^InpAtrRegimeBars=.*$", "InpAtrRegimeBars=$AtrRegimeBars"
  $ini = $ini -replace "(?m)^InpAtrRegimeMult=.*$", "InpAtrRegimeMult=$atrRegMultStr"
} else {
  $ini = $ini.TrimEnd() + "`r`nInpUseAtrRegime=$UseAtrRegime`r`nInpAtrRegimeBars=$AtrRegimeBars`r`nInpAtrRegimeMult=$atrRegMultStr`r`n"
}
if ($ini -match "(?m)^InpTrendOnZoneTf=") {
  $ini = $ini -replace "(?m)^InpTrendOnZoneTf=.*$", "InpTrendOnZoneTf=$TrendOnZoneTf"
} else {
  $ini = $ini.TrimEnd() + "`r`nInpTrendOnZoneTf=$TrendOnZoneTf`r`n"
}
$commStr = $CommissionPerLot.ToString($inv)
if ($ini -match "(?m)^InpSimCommission=") {
  $ini = $ini -replace "(?m)^InpSimCommission=.*$", "InpSimCommission=$SimCommission"
  $ini = $ini -replace "(?m)^InpCommissionPerLot=.*$", "InpCommissionPerLot=$commStr"
} else {
  $ini = $ini.TrimEnd() + "`r`nInpSimCommission=$SimCommission`r`nInpCommissionPerLot=$commStr`r`n"
}
Set-Content -Path $IniRun -Value $ini -Encoding ASCII

$candidates = @(
  (Join-Path $TerminalData "$ReportName.htm"),
  (Join-Path $TerminalData "$ReportName.html"),
  (Join-Path $TerminalData "Tester\$ReportName.htm"),
  (Join-Path $Mql5 "Files\$ReportName.htm")
)
foreach ($c in $candidates) {
  if (Test-Path $c) { Remove-Item $c -Force }
}

Get-Process terminal64 -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

Write-Host "== Launch Strategy Tester (headless) =="
Write-Host "Config: $IniRun"
Write-Host "Range: $FromDate -> $ToDate | Deposit=$Deposit | Model=$Model | $Period $Symbol | trendTF=$TrendTF zoneTrend=$TrendOnZoneTf zones=$ZoneTFs onePosPerTf=$OnePosPerTf | risk=$riskStr% qMode=$qMode($riskMinStr..$riskMaxStr) atrReg=$UseAtrRegime($AtrRegimeBars x$atrRegMultStr) | imp=$impStr body=$bodyStr fvg=$RequireFvg slow=$RequireSlow slx=$slStr trend=$RequireTrend rr=$RequireMinRr($rrStr) | guard=$UseGuard | comm=$SimCommission($commStr)"
$before = Get-Date
$p = Start-Process -FilePath $TerminalExe -ArgumentList "/config:`"$IniRun`"" -PassThru

$reportPath = $null
$deadline = (Get-Date).AddSeconds($TimeoutSec)
while ((Get-Date) -lt $deadline) {
  Start-Sleep -Seconds 8
  foreach ($c in $candidates) {
    if (Test-Path $c) {
      $len1 = (Get-Item $c).Length
      Start-Sleep -Seconds 2
      $len2 = (Get-Item $c).Length
      if ($len1 -gt 1000 -and $len1 -eq $len2) {
        $reportPath = $c
        break
      }
    }
  }
  if ($reportPath) { break }
  if ($p.HasExited -and -not $reportPath) {
    Start-Sleep -Seconds 3
    foreach ($c in $candidates) {
      if (Test-Path $c) { $reportPath = $c; break }
    }
    break
  }
  Write-Host ("  waiting... {0}s pid={1} exited={2}" -f [int]((Get-Date) - $before).TotalSeconds, $p.Id, $p.HasExited)
}

if (-not $reportPath) {
  throw "No report HTML found within ${TimeoutSec}s."
}

Write-Host "Report: $reportPath"
$html = Get-Content $reportPath -Raw

function Get-Stat([string]$label) {
  $pat = [regex]::Escape($label) + ':</td>\s*<td[^>]*>\s*(?:<b>)?([^<]+)'
  if ($html -match $pat) { return $Matches[1].Trim() }
  return "n/a"
}

$lines = @(
  "Report: $reportPath",
  "Symbol=$Symbol Period=$Period TrendTF=$TrendTF TrendOnZoneTf=$TrendOnZoneTf ZoneTFs=$ZoneTFs OnePosPerTf=$OnePosPerTf Deposit=$Deposit Model=$Model",
  "Risk=$riskStr QMode=$qMode($riskMinStr..$riskMaxStr) AtrReg=$UseAtrRegime($AtrRegimeBars x$atrRegMultStr) Impulse=$impStr Body=$bodyStr Bos=$RequireBos Fvg=$RequireFvg Slow=$RequireSlow SlowMax=$slowStr Slx=$slStr Trend=$RequireTrend MinRr=$RequireMinRr Rr=$rrStr Guard=$UseGuard Comm=$SimCommission($commStr)",
  "From=$FromDate To=$ToDate",
  "Total Net Profit: $(Get-Stat 'Total Net Profit')",
  "Gross Profit: $(Get-Stat 'Gross Profit')",
  "Gross Loss: $(Get-Stat 'Gross Loss')",
  "Profit Factor: $(Get-Stat 'Profit Factor')",
  "Expected Payoff: $(Get-Stat 'Expected Payoff')",
  "Equity DD Maximal: $(Get-Stat 'Equity Drawdown Maximal')",
  "Balance DD Maximal: $(Get-Stat 'Balance Drawdown Maximal')",
  "Total Trades: $(Get-Stat 'Total Trades')",
  "Profit Trades: $(Get-Stat 'Profit Trades (% of total)')",
  "Bars: $(Get-Stat 'Bars')"
)
$lines | Tee-Object -FilePath $SummaryOut
Write-Host "Summary saved: $SummaryOut"
