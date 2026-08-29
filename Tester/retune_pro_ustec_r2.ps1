#Requires -Version 5.1
$ErrorActionPreference = "Stop"
$tester = $PSScriptRoot
$run = Join-Path $tester "run_backtest.ps1"
$csv = Join-Path $tester "health_tune_pro_ustec_r2.csv"
Set-Content -Path $csv -Value "Preset,Net,ReturnPct,PF,EquityDD,Trades,WinRate,Notes" -Encoding ASCII

function Add-Row {
  param($SumPath, $Name, $Notes, $Deposit = 100000)
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
    $Period = "M15", $ZoneTFs = "M15",
    $SlZoneMult = 3.5,
    $RequireSlow = "false", $SlowMaxAtr = 0.7,
    $RequireMinRr = "true", $MinRiskReward = 1.8,
    $ImpulseAtrMult = 1.25, $BodyAtrMult = 0.65,
    [switch]$SkipCompile
  )
  Write-Host ""
  Write-Host ("======== {0} ======== {1}" -f $Name, $Notes)
  $args = @{
    Symbol = "USTEC_ExnessPro"; Period = $Period; TrendTF = "H4"; TrendOnZoneTf = "false"
    ZoneTFs = $ZoneTFs; OnePosPerTf = "false"
    FromDate = "2021.01.01"; ToDate = "2025.07.31"; Deposit = 100000; Model = 4; TimeoutSec = 14400
    ReportName = ("YorickSoS_{0}" -f $Name); RiskPct = 0.5; QualityMode = "0"
    RequireBos = "true"; RequireFvg = "true"; RequireSlow = $RequireSlow
    RequireTrend = "true"; RequireMinRr = $RequireMinRr; MinRiskReward = $MinRiskReward
    UseAtrRegime = "true"; AtrRegimeBars = 50; AtrRegimeMult = 1.5
    ImpulseAtrMult = $ImpulseAtrMult; BodyAtrMult = $BodyAtrMult; SlowMaxAtr = $SlowMaxAtr
    UseGuard = "true"; BeTriggerR = 0.5; TrailStartR = 0.5; TrailDistR = 0.5
    SimCommission = "false"; CommissionPerLot = 0; SlZoneMult = $SlZoneMult
  }
  if ($SkipCompile) { & $run @args -SkipCompile } else { & $run @args }
  if ($LASTEXITCODE -ne 0) { throw "failed $Name exit=$LASTEXITCODE" }
  Add-Row -SumPath (Join-Path $tester ("last_summary_YorickSoS_{0}.txt" -f $Name)) -Name $Name -Notes $Notes
}

Run-One -Name "pust2_base" -Notes "eur-style baseline"
Run-One -Name "pust2_rr15" -Notes "rr1.5" -MinRiskReward 1.5 -SkipCompile
Run-One -Name "pust2_rr20" -Notes "rr2.0" -MinRiskReward 2.0 -SkipCompile
Run-One -Name "pust2_rr25" -Notes "rr2.5" -MinRiskReward 2.5 -SkipCompile
Run-One -Name "pust2_slx25" -Notes "slx2.5" -SlZoneMult 2.5 -SkipCompile
Run-One -Name "pust2_slx40" -Notes "slx4.0" -SlZoneMult 4.0 -SkipCompile
Run-One -Name "pust2_imp15" -Notes "imp1.5" -ImpulseAtrMult 1.5 -BodyAtrMult 0.8 -SkipCompile
Run-One -Name "pust2_rr15_slx40" -Notes "rr1.5+slx4" -MinRiskReward 1.5 -SlZoneMult 4.0 -SkipCompile
Run-One -Name "pust2_m5_slow06" -Notes "M5 slow0.6" -Period "M5" -ZoneTFs "M5,M15" -RequireSlow "true" -SlowMaxAtr 0.6 -RequireMinRr "false" -SlZoneMult 2.0 -SkipCompile
Run-One -Name "pust2_m5_slow05" -Notes "M5 slow0.5" -Period "M5" -ZoneTFs "M5,M15" -RequireSlow "true" -SlowMaxAtr 0.5 -RequireMinRr "false" -SlZoneMult 2.0 -SkipCompile

Write-Host ""
Write-Host "======== CSV ========"
Get-Content $csv
