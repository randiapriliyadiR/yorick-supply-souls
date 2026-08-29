#Requires -Version 5.1
$ErrorActionPreference = "Stop"
$tester = $PSScriptRoot
$run = Join-Path $tester "run_backtest.ps1"
$csv = Join-Path $tester "health_tune_pro_xau.csv"
Set-Content -Path $csv -Value "Preset,Net,ReturnPct,PF,EquityDD,Trades,WinRate,Notes" -Encoding ASCII

function Add-Row {
  param($SumPath, $Name, $Notes)
  $Deposit = 200
  $txt = Get-Content $SumPath -Raw
  $net = if ($txt -match "Total Net Profit:\s*(.+)") { $Matches[1].Trim() } else { "?" }
  $pf  = if ($txt -match "Profit Factor:\s*(.+)") { $Matches[1].Trim() } else { "?" }
  $dd  = if ($txt -match "Equity DD Maximal:\s*(.+)") { $Matches[1].Trim() } else { "?" }
  $tr  = if ($txt -match "Total Trades:\s*(.+)") { $Matches[1].Trim() } else { "?" }
  $wr  = if ($txt -match "Profit Trades:\s*(.+)") { $Matches[1].Trim() } else { "?" }
  $netNum = 0.0
  if ($net -match "-?[\d\s]+(?:[\.,]\d+)?") { $netNum = [double](($Matches[0] -replace "\s","").Replace(",", ".")) }
  $ret = [math]::Round(100.0 * $netNum / $Deposit, 1)
  $line = ('"{0}","{1}","{2}","{3}","{4}","{5}","{6}","{7}"' -f $Name, $net, $ret, $pf, $dd, $tr, $wr, $Notes)
  Add-Content -Path $csv -Value $line -Encoding ASCII
  Write-Host ("ROW " + $line)
}

function Run-One {
  param(
    $Name, $Notes,
    $SlZoneMult = 2.0,
    $UseAtrRegime = "true", $AtrRegimeMult = 1.5,
    $ImpulseAtrMult = 1.25, $BodyAtrMult = 0.65,
    $SlowMaxAtr = 0.8, $RequireSlow = "true",
    $RequireMinRr = "false", $MinRiskReward = 2.5,
    $BeTriggerR = 0.5, $TrailStartR = 0.5, $TrailDistR = 0.5,
    [switch]$SkipCompile
  )
  Write-Host ""
  Write-Host ("======== {0} ======== {1}" -f $Name, $Notes)
  $args = @{
    Symbol = "XAUUSD_ExnessPro"; Period = "M5"; TrendTF = "H4"; TrendOnZoneTf = "false"
    ZoneTFs = "M5,M15"; OnePosPerTf = "false"
    FromDate = "2021.01.01"; ToDate = "2025.07.31"; Deposit = 200; Model = 4; TimeoutSec = 14400
    ReportName = ("YorickSoS_{0}" -f $Name); RiskPct = 0.5; QualityMode = "0"
    RequireBos = "true"; RequireFvg = "true"; RequireSlow = $RequireSlow
    RequireTrend = "true"; RequireMinRr = $RequireMinRr; MinRiskReward = $MinRiskReward
    UseAtrRegime = $UseAtrRegime; AtrRegimeBars = 50; AtrRegimeMult = $AtrRegimeMult
    ImpulseAtrMult = $ImpulseAtrMult; BodyAtrMult = $BodyAtrMult; SlowMaxAtr = $SlowMaxAtr
    UseGuard = "true"; BeTriggerR = $BeTriggerR; TrailStartR = $TrailStartR; TrailDistR = $TrailDistR
    SimCommission = "false"; CommissionPerLot = 0; SlZoneMult = $SlZoneMult
  }
  if ($SkipCompile) { & $run @args -SkipCompile } else { & $run @args }
  if ($LASTEXITCODE -ne 0) { throw "failed $Name exit=$LASTEXITCODE" }
  Add-Row -SumPath (Join-Path $tester ("last_summary_YorickSoS_{0}.txt" -f $Name)) -Name $Name -Notes $Notes
}

# Round 1: SL width + ATR regime (spread-aware)
Run-One -Name "prox_base" -Notes "baseline slx2 atr1.5"
Run-One -Name "prox_slx25" -Notes "slx2.5" -SlZoneMult 2.5 -SkipCompile
Run-One -Name "prox_slx30" -Notes "slx3.0" -SlZoneMult 3.0 -SkipCompile
Run-One -Name "prox_atroff" -Notes "atr OFF" -UseAtrRegime "false" -SkipCompile
Run-One -Name "prox_atr175" -Notes "atr 1.75" -AtrRegimeMult 1.75 -SkipCompile
Run-One -Name "prox_imp15" -Notes "impulse1.5 body0.8" -ImpulseAtrMult 1.5 -BodyAtrMult 0.8 -SkipCompile
Run-One -Name "prox_slow06" -Notes "slowMax0.6" -SlowMaxAtr 0.6 -SkipCompile
Run-One -Name "prox_guard10" -Notes "guard 1.0R" -BeTriggerR 1.0 -TrailStartR 1.0 -TrailDistR 1.0 -SkipCompile
Run-One -Name "prox_rr20" -Notes "minRR 2.0" -RequireMinRr "true" -MinRiskReward 2.0 -SkipCompile
Run-One -Name "prox_slx25_imp15" -Notes "slx2.5+imp1.5" -SlZoneMult 2.5 -ImpulseAtrMult 1.5 -BodyAtrMult 0.8 -SkipCompile

Write-Host ""
Write-Host "======== CSV ========"
Get-Content $csv
