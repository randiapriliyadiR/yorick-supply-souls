#Requires -Version 5.1
# USTEC from ORIGINAL VIDEO baseline (not XAU Pro-tuned SlowMax 0.7 / Guard 0.5R).
# Video: BOS+FVG+slow approach, SL zone buffer, trend gate, risk 2%.
$ErrorActionPreference = "Stop"
$tester = $PSScriptRoot
$run = Join-Path $tester "run_backtest.ps1"
$csv = Join-Path $tester "health_tune_pro_ustec_video.csv"
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
    $Name, $Notes, $Deposit = 100000,
    $Period = "D1", $TrendTF = "H4", $ZoneTFs = "D1",
    $RiskPct = 2.0,
    $SlowMaxAtr = 1.0, $RequireSlow = "true",
    $SlZoneMult = 2.0,
    $RequireMinRr = "false", $MinRiskReward = 2.5,
    $UseAtrRegime = "true", $AtrRegimeMult = 1.5,
    $BeTriggerR = 1.0, $TrailStartR = 1.0, $TrailDistR = 1.0,
    $RequireTrend = "true",
    [switch]$SkipCompile
  )
  Write-Host ""
  Write-Host ("======== {0} ======== {1}" -f $Name, $Notes)
  $args = @{
    Symbol = "USTEC_ExnessPro"; Period = $Period; TrendTF = $TrendTF; TrendOnZoneTf = "false"
    ZoneTFs = $ZoneTFs; OnePosPerTf = "false"
    FromDate = "2021.01.01"; ToDate = "2025.07.31"; Deposit = $Deposit; Model = 4; TimeoutSec = 14400
    ReportName = ("YorickSoS_{0}" -f $Name); RiskPct = $RiskPct; QualityMode = "0"
    RequireBos = "true"; RequireFvg = "true"; RequireSlow = $RequireSlow
    RequireTrend = $RequireTrend; RequireMinRr = $RequireMinRr; MinRiskReward = $MinRiskReward
    UseAtrRegime = $UseAtrRegime; AtrRegimeBars = 50; AtrRegimeMult = $AtrRegimeMult
    ImpulseAtrMult = 1.25; BodyAtrMult = 0.65; SlowMaxAtr = $SlowMaxAtr
    UseGuard = "true"; BeTriggerR = $BeTriggerR; TrailStartR = $TrailStartR; TrailDistR = $TrailDistR
    SimCommission = "false"; CommissionPerLot = 0; SlZoneMult = $SlZoneMult
  }
  if ($SkipCompile) { & $run @args -SkipCompile } else { & $run @args }
  if ($LASTEXITCODE -ne 0) { throw "failed $Name exit=$LASTEXITCODE" }
  Add-Row -SumPath (Join-Path $tester ("last_summary_YorickSoS_{0}.txt" -f $Name)) -Name $Name -Notes $Notes -Deposit $Deposit
}

# --- Round 0: video baseline @ risk 2% ---
Run-One -Name "pustV_d1_100k" -Notes "video D1 risk2 $100k" -Deposit 100000 -Period "D1" -ZoneTFs "D1" -TrendTF "W1"
Run-One -Name "pustV_d1_200" -Notes "video D1 risk2 $200" -Deposit 200 -Period "D1" -ZoneTFs "D1" -TrendTF "W1" -SkipCompile
Run-One -Name "pustV_h4_100k" -Notes "video H4 zones H4 risk2" -Deposit 100000 -Period "H4" -ZoneTFs "H4" -TrendTF "D1" -SkipCompile
Run-One -Name "pustV_h1_100k" -Notes "video H1 zones H1 risk2" -Deposit 100000 -Period "H1" -ZoneTFs "H1" -TrendTF "H4" -SkipCompile
Run-One -Name "pustV_m5_100k" -Notes "video M5/M15 risk2 (pre-XAU slow1.0 guard1R)" -Deposit 100000 -Period "M5" -ZoneTFs "M5,M15" -TrendTF "H4" -SkipCompile
Run-One -Name "pustV_m5_200" -Notes "video M5 risk2 $200" -Deposit 200 -Period "M5" -ZoneTFs "M5,M15" -TrendTF "H4" -SkipCompile

# --- Round 1: light tune around whichever gets trades ---
Run-One -Name "pustV_m5_slow08" -Notes "M5 slowMax0.8" -Deposit 100000 -Period "M5" -ZoneTFs "M5,M15" -SlowMaxAtr 0.8 -SkipCompile
Run-One -Name "pustV_m5_slow12" -Notes "M5 slowMax1.2" -Deposit 100000 -Period "M5" -ZoneTFs "M5,M15" -SlowMaxAtr 1.2 -SkipCompile
Run-One -Name "pustV_m5_slx15" -Notes "M5 slx1.5" -Deposit 100000 -Period "M5" -ZoneTFs "M5,M15" -SlZoneMult 1.5 -SkipCompile
Run-One -Name "pustV_m5_slx25" -Notes "M5 slx2.5" -Deposit 100000 -Period "M5" -ZoneTFs "M5,M15" -SlZoneMult 2.5 -SkipCompile
Run-One -Name "pustV_m5_atroff" -Notes "M5 atr OFF" -Deposit 100000 -Period "M5" -ZoneTFs "M5,M15" -UseAtrRegime "false" -SkipCompile
Run-One -Name "pustV_m5_soff" -Notes "M5 slow OFF" -Deposit 100000 -Period "M5" -ZoneTFs "M5,M15" -RequireSlow "false" -SkipCompile
Run-One -Name "pustV_h1_slow12" -Notes "H1 slow1.2" -Deposit 100000 -Period "H1" -ZoneTFs "H1" -TrendTF "H4" -SlowMaxAtr 1.2 -SkipCompile
Run-One -Name "pustV_h1_slx15" -Notes "H1 slx1.5" -Deposit 100000 -Period "H1" -ZoneTFs "H1" -TrendTF "H4" -SlZoneMult 1.5 -SkipCompile
Run-One -Name "pustV_d1_slx15" -Notes "D1 slx1.5" -Deposit 100000 -Period "D1" -ZoneTFs "D1" -TrendTF "W1" -SlZoneMult 1.5 -SkipCompile
Run-One -Name "pustV_d1_soff" -Notes "D1 slow OFF" -Deposit 100000 -Period "D1" -ZoneTFs "D1" -TrendTF "W1" -RequireSlow "false" -SkipCompile

Write-Host ""
Write-Host "======== CSV ========"
Get-Content $csv
