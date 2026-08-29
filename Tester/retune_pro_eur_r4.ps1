#Requires -Version 5.1
$ErrorActionPreference = "Stop"
$tester = $PSScriptRoot
$run = Join-Path $tester "run_backtest.ps1"
$csv = Join-Path $tester "health_tune_pro_eur_r4.csv"
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
    $Name, $Notes, $Deposit = 200,
    $ZoneTFs = "M15,H1",
    $SlZoneMult = 2.5,
    $MinRiskReward = 2.0,
    $ImpulseAtrMult = 1.25, $BodyAtrMult = 0.65,
    [switch]$SkipCompile
  )
  Write-Host ""
  Write-Host ("======== {0} ======== {1}" -f $Name, $Notes)
  $args = @{
    Symbol = "EURUSD_ExnessPro"; Period = "M15"; TrendTF = "H4"; TrendOnZoneTf = "false"
    ZoneTFs = $ZoneTFs; OnePosPerTf = "false"
    FromDate = "2021.01.01"; ToDate = "2025.12.31"; Deposit = $Deposit; Model = 4; TimeoutSec = 14400
    ReportName = ("YorickSoS_{0}" -f $Name); RiskPct = 0.5; QualityMode = "0"
    RequireBos = "true"; RequireFvg = "true"; RequireSlow = "false"
    RequireTrend = "true"; RequireMinRr = "true"; MinRiskReward = $MinRiskReward
    UseAtrRegime = "true"; AtrRegimeBars = 50; AtrRegimeMult = 1.5
    ImpulseAtrMult = $ImpulseAtrMult; BodyAtrMult = $BodyAtrMult; SlowMaxAtr = 0.7
    UseGuard = "true"; BeTriggerR = 0.5; TrailStartR = 0.5; TrailDistR = 0.5
    SimCommission = "false"; CommissionPerLot = 0; SlZoneMult = $SlZoneMult
  }
  if ($SkipCompile) { & $run @args -SkipCompile } else { & $run @args }
  if ($LASTEXITCODE -ne 0) { throw "failed $Name exit=$LASTEXITCODE" }
  Add-Row -SumPath (Join-Path $tester ("last_summary_YorickSoS_{0}.txt" -f $Name)) -Name $Name -Notes $Notes -Deposit $Deposit
}

Run-One -Name "peur4_rr20" -Notes "winner baseline rr2"
Run-One -Name "peur4_rr18" -Notes "rr1.8" -MinRiskReward 1.8 -SkipCompile
Run-One -Name "peur4_rr22" -Notes "rr2.2" -MinRiskReward 2.2 -SkipCompile
Run-One -Name "peur4_rr20_slx35" -Notes "rr2+slx3.5" -SlZoneMult 3.5 -SkipCompile
Run-One -Name "peur4_rr20_slx30" -Notes "rr2+slx3" -SlZoneMult 3.0 -SkipCompile
Run-One -Name "peur4_rr20_m15z" -Notes "rr2 zones M15" -ZoneTFs "M15" -SkipCompile
Run-One -Name "peur4_rr20_imp15" -Notes "rr2 imp1.5" -ImpulseAtrMult 1.5 -BodyAtrMult 0.8 -SkipCompile
Run-One -Name "peur4_rr20_slx35_m15z" -Notes "rr2+slx3.5+M15z" -SlZoneMult 3.5 -ZoneTFs "M15" -SkipCompile
Run-One -Name "peur4_rr20_slx35_imp15" -Notes "rr2+slx3.5+imp1.5" -SlZoneMult 3.5 -ImpulseAtrMult 1.5 -BodyAtrMult 0.8 -SkipCompile
Run-One -Name "peur4_rr20_100k" -Notes "winner $100k confirm" -Deposit 100000 -SkipCompile

Write-Host ""
Write-Host "======== CSV ========"
Get-Content $csv
