#Requires -Version 5.1
$ErrorActionPreference = "Stop"
$tester = $PSScriptRoot
$run = Join-Path $tester "run_backtest.ps1"
$csv = Join-Path $tester "health_tune_pro_xau.csv"

function Add-Row {
  param($SumPath, $Name, $Deposit, $Notes)
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
  param($Name, $Deposit, $Notes, $SlowMaxAtr = 0.6, [switch]$SkipCompile)
  Write-Host ""
  Write-Host ("======== {0} ========" -f $Name)
  $args = @{
    Symbol = "XAUUSD_ExnessPro"; Period = "M5"; TrendTF = "H4"; TrendOnZoneTf = "false"
    ZoneTFs = "M5,M15"; OnePosPerTf = "false"
    FromDate = "2021.01.01"; ToDate = "2025.07.31"; Deposit = $Deposit; Model = 4; TimeoutSec = 14400
    ReportName = ("YorickSoS_{0}" -f $Name); RiskPct = 0.5; QualityMode = "0"
    RequireBos = "true"; RequireFvg = "true"; RequireSlow = "true"
    RequireTrend = "true"; RequireMinRr = "false"; MinRiskReward = 2.5
    UseAtrRegime = "true"; AtrRegimeBars = 50; AtrRegimeMult = 1.5
    ImpulseAtrMult = 1.25; BodyAtrMult = 0.65; SlowMaxAtr = $SlowMaxAtr
    UseGuard = "true"; BeTriggerR = 0.5; TrailStartR = 0.5; TrailDistR = 0.5
    SimCommission = "false"; CommissionPerLot = 0; SlZoneMult = 2.0
  }
  if ($SkipCompile) { & $run @args -SkipCompile } else { & $run @args }
  if ($LASTEXITCODE -ne 0) { throw "failed $Name" }
  Add-Row -SumPath (Join-Path $tester ("last_summary_YorickSoS_{0}.txt" -f $Name)) -Name $Name -Deposit $Deposit -Notes $Notes
}

Run-One -Name "prox_slow05" -Deposit 200 -Notes "slowMax0.5" -SlowMaxAtr 0.5
Run-One -Name "prox_slow07" -Deposit 200 -Notes "slowMax0.7" -SlowMaxAtr 0.7 -SkipCompile
Run-One -Name "prox_slow06_100k" -Deposit 100000 -Notes "slowMax0.6 $100k" -SlowMaxAtr 0.6 -SkipCompile
Run-One -Name "prox_base_100k" -Deposit 100000 -Notes "baseline $100k" -SlowMaxAtr 0.8 -SkipCompile

Write-Host ""
Write-Host "======== CSV ========"
Get-Content $csv
