#Requires -Version 5.1
$ErrorActionPreference = "Stop"
$tester = $PSScriptRoot
$run = Join-Path $tester "run_backtest.ps1"
$csv = Join-Path $tester "health_tune_pro_eur_risk.csv"
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
    $RiskPct = 0.5,
    $ZoneTFs = "M15",
    $SlZoneMult = 3.5,
    $RequireMinRr = "true", $MinRiskReward = 1.8,
    $ImpulseAtrMult = 1.25, $BodyAtrMult = 0.65,
    $BeTriggerR = 0.5, $TrailStartR = 0.5, $TrailDistR = 0.5,
    [switch]$SkipCompile
  )
  Write-Host ""
  Write-Host ("======== {0} ======== {1}" -f $Name, $Notes)
  $args = @{
    Symbol = "EURUSD_ExnessPro"; Period = "M15"; TrendTF = "H4"; TrendOnZoneTf = "false"
    ZoneTFs = $ZoneTFs; OnePosPerTf = "false"
    FromDate = "2021.01.01"; ToDate = "2025.12.31"; Deposit = $Deposit; Model = 4; TimeoutSec = 14400
    ReportName = ("YorickSoS_{0}" -f $Name); RiskPct = $RiskPct; QualityMode = "0"
    RequireBos = "true"; RequireFvg = "true"; RequireSlow = "false"
    RequireTrend = "true"; RequireMinRr = $RequireMinRr; MinRiskReward = $MinRiskReward
    UseAtrRegime = "true"; AtrRegimeBars = 50; AtrRegimeMult = 1.5
    ImpulseAtrMult = $ImpulseAtrMult; BodyAtrMult = $BodyAtrMult; SlowMaxAtr = 0.7
    UseGuard = "true"; BeTriggerR = $BeTriggerR; TrailStartR = $TrailStartR; TrailDistR = $TrailDistR
    SimCommission = "false"; CommissionPerLot = 0; SlZoneMult = $SlZoneMult
  }
  if ($SkipCompile) { & $run @args -SkipCompile } else { & $run @args }
  if ($LASTEXITCODE -ne 0) { throw "failed $Name exit=$LASTEXITCODE" }
  Add-Row -SumPath (Join-Path $tester ("last_summary_YorickSoS_{0}.txt" -f $Name)) -Name $Name -Notes $Notes -Deposit $Deposit
}

# Scale risk on current winner
Run-One -Name "peurR_r05" -Notes "winner risk0.5" -RiskPct 0.5
Run-One -Name "peurR_r10" -Notes "risk1.0" -RiskPct 1.0 -SkipCompile
Run-One -Name "peurR_r15" -Notes "risk1.5" -RiskPct 1.5 -SkipCompile
Run-One -Name "peurR_r20" -Notes "risk2.0" -RiskPct 2.0 -SkipCompile
Run-One -Name "peurR_r25" -Notes "risk2.5" -RiskPct 2.5 -SkipCompile

# Looser entry filters @ risk1.5 (mid aggression)
Run-One -Name "peurR_rr15" -Notes "risk1.5 rr1.5" -RiskPct 1.5 -MinRiskReward 1.5 -SkipCompile
Run-One -Name "peurR_rr12" -Notes "risk1.5 rr1.2" -RiskPct 1.5 -MinRiskReward 1.2 -SkipCompile
Run-One -Name "peurR_rroff" -Notes "risk1.5 rrOFF" -RiskPct 1.5 -RequireMinRr "false" -SkipCompile
Run-One -Name "peurR_zh1" -Notes "risk1.5 zones M15,H1" -RiskPct 1.5 -ZoneTFs "M15,H1" -SkipCompile
Run-One -Name "peurR_slx25" -Notes "risk1.5 slx2.5" -RiskPct 1.5 -SlZoneMult 2.5 -SkipCompile
Run-One -Name "peurR_rr15_zh1" -Notes "risk1.5 rr1.5+M15H1" -RiskPct 1.5 -MinRiskReward 1.5 -ZoneTFs "M15,H1" -SkipCompile
Run-One -Name "peurR_r20_rr15" -Notes "risk2.0 rr1.5" -RiskPct 2.0 -MinRiskReward 1.5 -SkipCompile

Write-Host ""
Write-Host "======== CSV ========"
Get-Content $csv
