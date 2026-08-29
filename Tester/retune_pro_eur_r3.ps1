#Requires -Version 5.1
$ErrorActionPreference = "Stop"
$tester = $PSScriptRoot
$run = Join-Path $tester "run_backtest.ps1"
$csv = Join-Path $tester "health_tune_pro_eur_r3.csv"
Set-Content -Path $csv -Value "Preset,Net,ReturnPct,PF,EquityDD,Trades,WinRate,Notes" -Encoding ASCII

function Add-Row {
  param($SumPath, $Name, $Notes, $Deposit = 200)
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
    $ZoneTFs = "M15,H1",
    $SlZoneMult = 2.5,
    $RequireSlow = "false", $SlowMaxAtr = 0.7,
    $RequireMinRr = "false", $MinRiskReward = 2.5,
    $ImpulseAtrMult = 1.25, $BodyAtrMult = 0.65,
    $QualityMode = "0",
    $BeTriggerR = 0.5, $TrailStartR = 0.5, $TrailDistR = 0.5,
    $TrendTF = "H4",
    [switch]$SkipCompile
  )
  Write-Host ""
  Write-Host ("======== {0} ======== {1}" -f $Name, $Notes)
  $args = @{
    Symbol = "EURUSD_ExnessPro"; Period = "M15"; TrendTF = $TrendTF; TrendOnZoneTf = "false"
    ZoneTFs = $ZoneTFs; OnePosPerTf = "false"
    FromDate = "2021.01.01"; ToDate = "2025.12.31"; Deposit = 200; Model = 4; TimeoutSec = 14400
    ReportName = ("YorickSoS_{0}" -f $Name); RiskPct = 0.5; QualityMode = $QualityMode
    RequireBos = "true"; RequireFvg = "true"; RequireSlow = $RequireSlow
    RequireTrend = "true"; RequireMinRr = $RequireMinRr; MinRiskReward = $MinRiskReward
    UseAtrRegime = "true"; AtrRegimeBars = 50; AtrRegimeMult = 1.5
    ImpulseAtrMult = $ImpulseAtrMult; BodyAtrMult = $BodyAtrMult; SlowMaxAtr = $SlowMaxAtr
    UseGuard = "true"; BeTriggerR = $BeTriggerR; TrailStartR = $TrailStartR; TrailDistR = $TrailDistR
    SimCommission = "false"; CommissionPerLot = 0; SlZoneMult = $SlZoneMult
  }
  if ($SkipCompile) { & $run @args -SkipCompile } else { & $run @args }
  if ($LASTEXITCODE -ne 0) { throw "failed $Name exit=$LASTEXITCODE" }
  Add-Row -SumPath (Join-Path $tester ("last_summary_YorickSoS_{0}.txt" -f $Name)) -Name $Name -Notes $Notes
}

Run-One -Name "peur3_base" -Notes "M15 soff slx2.5 baseline"
Run-One -Name "peur3_rr20" -Notes "+minRR2" -RequireMinRr "true" -MinRiskReward 2.0 -SkipCompile
Run-One -Name "peur3_rr25" -Notes "+minRR2.5" -RequireMinRr "true" -MinRiskReward 2.5 -SkipCompile
Run-One -Name "peur3_rr30" -Notes "+minRR3" -RequireMinRr "true" -MinRiskReward 3.0 -SkipCompile
Run-One -Name "peur3_slx30" -Notes "slx3" -SlZoneMult 3.0 -SkipCompile
Run-One -Name "peur3_slx35" -Notes "slx3.5" -SlZoneMult 3.5 -SkipCompile
Run-One -Name "peur3_imp15" -Notes "imp1.5" -ImpulseAtrMult 1.5 -BodyAtrMult 0.8 -SkipCompile
Run-One -Name "peur3_qa" -Notes "quality A" -QualityMode "1" -SkipCompile
Run-One -Name "peur3_rr25_slx30" -Notes "rr2.5+slx3" -RequireMinRr "true" -MinRiskReward 2.5 -SlZoneMult 3.0 -SkipCompile
Run-One -Name "peur3_rr30_slx30" -Notes "rr3+slx3" -RequireMinRr "true" -MinRiskReward 3.0 -SlZoneMult 3.0 -SkipCompile
Run-One -Name "peur3_zones_m15" -Notes "zones M15 only" -ZoneTFs "M15" -SkipCompile
Run-One -Name "peur3_zones_h1" -Notes "zones H1 only" -ZoneTFs "H1" -SkipCompile
Run-One -Name "peur3_d1" -Notes "trend D1" -TrendTF "D1" -SkipCompile
Run-One -Name "peur3_guard10" -Notes "guard1R" -BeTriggerR 1.0 -TrailStartR 1.0 -TrailDistR 1.0 -SkipCompile

Write-Host ""
Write-Host "======== CSV ========"
Get-Content $csv
