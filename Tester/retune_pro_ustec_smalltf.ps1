#Requires -Version 5.1
$ErrorActionPreference = "Stop"
$tester = $PSScriptRoot
$run = Join-Path $tester "run_backtest.ps1"
$csv = Join-Path $tester "health_tune_pro_ustec_smalltf.csv"
Set-Content -Path $csv -Value "Preset,Net,ReturnPct,PF,EquityDD,Trades,WinRate,Notes" -Encoding ASCII

function Add-Row {
  param($SumPath, $Name, $Notes, $Deposit)
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
    $Name, $Notes, $Deposit,
    $Period, $ZoneTFs,
    $RiskPct = 0.5,
    $SlZoneMult = 2.0,
    $RequireSlow = "true", $SlowMaxAtr = 0.7,
    $RequireMinRr = "false", $MinRiskReward = 1.5,
    $RequireBos = "true", $RequireFvg = "true", $RequireTrend = "true",
    $UseAtrRegime = "true",
    [switch]$SkipCompile
  )
  Write-Host ""
  Write-Host ("======== {0} ======== {1}" -f $Name, $Notes)
  $args = @{
    Symbol = "USTEC_ExnessPro"; Period = $Period; TrendTF = "H1"; TrendOnZoneTf = "false"
    ZoneTFs = $ZoneTFs; OnePosPerTf = "false"
    FromDate = "2021.01.01"; ToDate = "2025.07.31"; Deposit = $Deposit; Model = 4; TimeoutSec = 14400
    ReportName = ("YorickSoS_{0}" -f $Name); RiskPct = $RiskPct; QualityMode = "0"
    RequireBos = $RequireBos; RequireFvg = $RequireFvg; RequireSlow = $RequireSlow
    RequireTrend = $RequireTrend; RequireMinRr = $RequireMinRr; MinRiskReward = $MinRiskReward
    UseAtrRegime = $UseAtrRegime; AtrRegimeBars = 50; AtrRegimeMult = 1.5
    ImpulseAtrMult = 1.25; BodyAtrMult = 0.65; SlowMaxAtr = $SlowMaxAtr
    UseGuard = "true"; BeTriggerR = 0.5; TrailStartR = 0.5; TrailDistR = 0.5
    SimCommission = "false"; CommissionPerLot = 0; SlZoneMult = $SlZoneMult
  }
  if ($SkipCompile) { & $run @args -SkipCompile } else { & $run @args }
  if ($LASTEXITCODE -ne 0) { throw "failed $Name exit=$LASTEXITCODE" }
  Add-Row -SumPath (Join-Path $tester ("last_summary_YorickSoS_{0}.txt" -f $Name)) -Name $Name -Notes $Notes -Deposit $Deposit
}

# Sizing probes on small TF @ $200 first
Run-One -Name "pustS_m1_200" -Notes "M1 zones M1,M5 $200" -Deposit 200 -Period "M1" -ZoneTFs "M1,M5" -SlZoneMult 1.5
Run-One -Name "pustS_m1_open200" -Notes "M1 open filters $200" -Deposit 200 -Period "M1" -ZoneTFs "M1,M5" -SlZoneMult 1.5 `
  -RequireBos "false" -RequireFvg "false" -RequireSlow "false" -RequireTrend "false" -UseAtrRegime "false" -SkipCompile
Run-One -Name "pustS_m5_m1z_200" -Notes "M5 zones M1,M5 $200" -Deposit 200 -Period "M5" -ZoneTFs "M1,M5" -SlZoneMult 1.5 -SkipCompile
Run-One -Name "pustS_m5_open200" -Notes "M5 open $200" -Deposit 200 -Period "M5" -ZoneTFs "M1,M5" -SlZoneMult 1.5 `
  -RequireBos "false" -RequireFvg "false" -RequireSlow "false" -RequireTrend "false" -UseAtrRegime "false" -SkipCompile

# Same on $100k for edge
Run-One -Name "pustS_m1_100k" -Notes "M1 zones M1,M5 $100k" -Deposit 100000 -Period "M1" -ZoneTFs "M1,M5" -SlZoneMult 1.5 -SkipCompile
Run-One -Name "pustS_m1_slow05" -Notes "M1 slow0.5 $100k" -Deposit 100000 -Period "M1" -ZoneTFs "M1,M5" -SlowMaxAtr 0.5 -SlZoneMult 1.5 -SkipCompile
Run-One -Name "pustS_m1_soff_rr15" -Notes "M1 soff rr1.5 $100k" -Deposit 100000 -Period "M1" -ZoneTFs "M1,M5" `
  -RequireSlow "false" -RequireMinRr "true" -MinRiskReward 1.5 -SlZoneMult 2.0 -SkipCompile
Run-One -Name "pustS_m5_m1z_100k" -Notes "M5 zones M1,M5 $100k" -Deposit 100000 -Period "M5" -ZoneTFs "M1,M5" -SlZoneMult 1.5 -SkipCompile
Run-One -Name "pustS_m5_slow05" -Notes "M5 slow0.5 zones M1 $100k" -Deposit 100000 -Period "M5" -ZoneTFs "M1,M5" -SlowMaxAtr 0.5 -SlZoneMult 1.5 -SkipCompile
Run-One -Name "pustS_m1_risk15" -Notes "M1 risk1.5 $200" -Deposit 200 -Period "M1" -ZoneTFs "M1,M5" -RiskPct 1.5 -SlZoneMult 1.5 -SkipCompile
Run-One -Name "pustS_m1_risk50" -Notes "M1 risk5 $200" -Deposit 200 -Period "M1" -ZoneTFs "M1,M5" -RiskPct 5.0 -SlZoneMult 1.5 -SkipCompile

Write-Host ""
Write-Host "======== CSV ========"
Get-Content $csv
