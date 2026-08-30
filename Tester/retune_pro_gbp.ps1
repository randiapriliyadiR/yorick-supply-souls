#Requires -Version 5.1
# GBPUSD Pro discovery: EUR winner stack + video baselines + XAU-style (do not assume copy works).
$ErrorActionPreference = "Stop"
$tester = $PSScriptRoot
$run = Join-Path $tester "run_backtest.ps1"
$csv = Join-Path $tester "health_tune_pro_gbp.csv"
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
    $Name, $Notes, $Deposit = 100000,
    $Period = "M15", $TrendTF = "H4", $ZoneTFs = "M15",
    $RiskPct = 1.5,
    $SlowMaxAtr = 0.7, $RequireSlow = "false",
    $SlZoneMult = 3.5,
    $RequireMinRr = "true", $MinRiskReward = 1.5,
    $RequireFvg = "true",
    $UseAtrRegime = "true", $AtrRegimeMult = 1.5,
    $ImpulseAtrMult = 1.25, $BodyAtrMult = 0.65,
    $BeTriggerR = 0.5, $TrailStartR = 0.5, $TrailDistR = 0.5,
    [switch]$SkipCompile
  )
  Write-Host ""
  Write-Host ("======== {0} ======== {1}" -f $Name, $Notes)
  $args = @{
    Symbol = "GBPUSD_ExnessPro"; Period = $Period; TrendTF = $TrendTF; TrendOnZoneTf = "false"
    ZoneTFs = $ZoneTFs; OnePosPerTf = "false"
    FromDate = "2021.01.01"; ToDate = "2025.12.22"; Deposit = $Deposit; Model = 4; TimeoutSec = 14400
    ReportName = ("YorickSoS_{0}" -f $Name); RiskPct = $RiskPct; QualityMode = "0"
    RequireBos = "true"; RequireFvg = $RequireFvg; RequireSlow = $RequireSlow
    RequireTrend = "true"; RequireMinRr = $RequireMinRr; MinRiskReward = $MinRiskReward
    UseAtrRegime = $UseAtrRegime; AtrRegimeBars = 50; AtrRegimeMult = $AtrRegimeMult
    ImpulseAtrMult = $ImpulseAtrMult; BodyAtrMult = $BodyAtrMult; SlowMaxAtr = $SlowMaxAtr
    UseGuard = "true"; BeTriggerR = $BeTriggerR; TrailStartR = $TrailStartR; TrailDistR = $TrailDistR
    SimCommission = "false"; CommissionPerLot = 0; SlZoneMult = $SlZoneMult
  }
  if ($SkipCompile) { & $run @args -SkipCompile } else { & $run @args }
  if ($LASTEXITCODE -ne 0) { throw "failed $Name exit=$LASTEXITCODE" }
  Add-Row -SumPath (Join-Path $tester ("last_summary_YorickSoS_{0}.txt" -f $Name)) -Name $Name -Notes $Notes -Deposit $Deposit
}

# Round 0: stacks that worked (or failed) on sibling pairs
Run-One -Name "pgbp_eurbest" -Notes "EUR Best stack M15 risk1.5 rr1.5 slx3.5 soff"
Run-One -Name "pgbp_eursafe" -Notes "EUR Safe risk0.5 rr1.8" -RiskPct 0.5 -MinRiskReward 1.8 -SkipCompile
Run-One -Name "pgbp_xaum5" -Notes "XAU Pro M5 slow0.7" -Period "M5" -ZoneTFs "M5,M15" -RiskPct 0.5 -RequireSlow "true" -SlowMaxAtr 0.7 -SlZoneMult 2.0 -RequireMinRr "false" -SkipCompile
Run-One -Name "pgbp_vid_m15" -Notes "video M15 slow1.0 guard1R risk2" -RiskPct 2.0 -RequireSlow "true" -SlowMaxAtr 1.0 -SlZoneMult 2.0 -RequireMinRr "false" -BeTriggerR 1.0 -TrailStartR 1.0 -TrailDistR 1.0 -SkipCompile
Run-One -Name "pgbp_vid_h1" -Notes "video H1" -Period "H1" -ZoneTFs "H1" -TrendTF "H4" -RiskPct 2.0 -RequireSlow "true" -SlowMaxAtr 1.0 -SlZoneMult 2.0 -RequireMinRr "false" -BeTriggerR 1.0 -TrailStartR 1.0 -TrailDistR 1.0 -SkipCompile
Run-One -Name "pgbp_vid_h4" -Notes "video H4" -Period "H4" -ZoneTFs "H4" -TrendTF "D1" -RiskPct 2.0 -RequireSlow "true" -SlowMaxAtr 1.0 -SlZoneMult 2.0 -RequireMinRr "false" -BeTriggerR 1.0 -TrailStartR 1.0 -TrailDistR 1.0 -SkipCompile
Run-One -Name "pgbp_m15_slow07" -Notes "M15 slowON 0.7" -RequireSlow "true" -SlowMaxAtr 0.7 -SlZoneMult 2.0 -RequireMinRr "false" -RiskPct 1.5 -SkipCompile
Run-One -Name "pgbp_eurbest_200" -Notes "EUR Best $200" -Deposit 200 -SkipCompile

Write-Host ""
Write-Host "======== CSV ========"
Get-Content $csv
