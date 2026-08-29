#Requires -Version 5.1
$ErrorActionPreference = "Stop"
$tester = $PSScriptRoot
$run = Join-Path $tester "run_backtest.ps1"
$csv = Join-Path $tester "health_tune_pro_eur_r2.csv"
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
    $Period = "M5", $TrendTF = "H4", $ZoneTFs = "M5,M15",
    $SlZoneMult = 2.5,
    $RequireSlow = "false", $SlowMaxAtr = 0.7,
    $RequireFvg = "true", $RequireTrend = "true",
    $RequireMinRr = "false", $MinRiskReward = 2.5,
    $ImpulseAtrMult = 1.25, $BodyAtrMult = 0.65,
    $QualityMode = "0",
    $BeTriggerR = 0.5, $TrailStartR = 0.5, $TrailDistR = 0.5,
    [switch]$SkipCompile
  )
  Write-Host ""
  Write-Host ("======== {0} ======== {1}" -f $Name, $Notes)
  $args = @{
    Symbol = "EURUSD_ExnessPro"; Period = $Period; TrendTF = $TrendTF; TrendOnZoneTf = "false"
    ZoneTFs = $ZoneTFs; OnePosPerTf = "false"
    FromDate = "2021.01.01"; ToDate = "2025.12.31"; Deposit = 200; Model = 4; TimeoutSec = 14400
    ReportName = ("YorickSoS_{0}" -f $Name); RiskPct = 0.5; QualityMode = $QualityMode
    RequireBos = "true"; RequireFvg = $RequireFvg; RequireSlow = $RequireSlow
    RequireTrend = $RequireTrend; RequireMinRr = $RequireMinRr; MinRiskReward = $MinRiskReward
    UseAtrRegime = "true"; AtrRegimeBars = 50; AtrRegimeMult = 1.5
    ImpulseAtrMult = $ImpulseAtrMult; BodyAtrMult = $BodyAtrMult; SlowMaxAtr = $SlowMaxAtr
    UseGuard = "true"; BeTriggerR = $BeTriggerR; TrailStartR = $TrailStartR; TrailDistR = $TrailDistR
    SimCommission = "false"; CommissionPerLot = 0; SlZoneMult = $SlZoneMult
  }
  if ($SkipCompile) { & $run @args -SkipCompile } else { & $run @args }
  if ($LASTEXITCODE -ne 0) { throw "failed $Name exit=$LASTEXITCODE" }
  Add-Row -SumPath (Join-Path $tester ("last_summary_YorickSoS_{0}.txt" -f $Name)) -Name $Name -Notes $Notes
}

# Round 2: filter the slowOFF stream (best PF 0.75) + alt TF stack
Run-One -Name "peur2_soff_rr20" -Notes "slowOFF slx2.5 minRR2" -RequireMinRr "true" -MinRiskReward 2.0
Run-One -Name "peur2_soff_rr25" -Notes "slowOFF slx2.5 minRR2.5" -RequireMinRr "true" -MinRiskReward 2.5 -SkipCompile
Run-One -Name "peur2_soff_rr30" -Notes "slowOFF slx2.5 minRR3" -RequireMinRr "true" -MinRiskReward 3.0 -SkipCompile
Run-One -Name "peur2_soff_qa" -Notes "slowOFF quality A" -QualityMode "1" -SkipCompile
Run-One -Name "peur2_soff_qc" -Notes "slowOFF quality C" -QualityMode "2" -SkipCompile
Run-One -Name "peur2_soff_imp15" -Notes "slowOFF imp1.5" -ImpulseAtrMult 1.5 -BodyAtrMult 0.8 -SkipCompile
Run-One -Name "peur2_soff_slx35" -Notes "slowOFF slx3.5" -SlZoneMult 3.5 -SkipCompile
Run-One -Name "peur2_soff_guard10" -Notes "slowOFF guard1R" -BeTriggerR 1.0 -TrailStartR 1.0 -TrailDistR 1.0 -SkipCompile
Run-One -Name "peur2_m15" -Notes "chart M15 zones M15,H1" -Period "M15" -ZoneTFs "M15,H1" -RequireSlow "true" -SlowMaxAtr 0.7 -SlZoneMult 2.0 -SkipCompile
Run-One -Name "peur2_m15_soff" -Notes "M15 slowOFF" -Period "M15" -ZoneTFs "M15,H1" -RequireSlow "false" -SlZoneMult 2.5 -SkipCompile
Run-One -Name "peur2_trendoff" -Notes "trend OFF slowON 0.7" -RequireTrend "false" -RequireSlow "true" -SlZoneMult 2.0 -SkipCompile
Run-One -Name "peur2_d1trend" -Notes "trend D1" -TrendTF "D1" -RequireSlow "true" -SlZoneMult 2.0 -SkipCompile

Write-Host ""
Write-Host "======== CSV ========"
Get-Content $csv
