#Requires -Version 5.1
$ErrorActionPreference = "Stop"
$tester = $PSScriptRoot
$run = Join-Path $tester "run_backtest.ps1"
$csv = Join-Path $tester "health_tune_pro_ustec_video_h4.csv"
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
    $ZoneTFs = "H4",
    $SlowMaxAtr = 1.0, $RequireSlow = "true",
    $SlZoneMult = 2.0,
    $UseAtrRegime = "true",
    $BeTriggerR = 1.0, $TrailStartR = 1.0, $TrailDistR = 1.0,
    $RequireMinRr = "false", $MinRiskReward = 1.5,
    [switch]$SkipCompile
  )
  Write-Host ""
  Write-Host ("======== {0} ======== {1}" -f $Name, $Notes)
  $args = @{
    Symbol = "USTEC_ExnessPro"; Period = "H4"; TrendTF = "D1"; TrendOnZoneTf = "false"
    ZoneTFs = $ZoneTFs; OnePosPerTf = "false"
    FromDate = "2021.01.01"; ToDate = "2025.07.31"; Deposit = $Deposit; Model = 4; TimeoutSec = 14400
    ReportName = ("YorickSoS_{0}" -f $Name); RiskPct = 2.0; QualityMode = "0"
    RequireBos = "true"; RequireFvg = "true"; RequireSlow = $RequireSlow
    RequireTrend = "true"; RequireMinRr = $RequireMinRr; MinRiskReward = $MinRiskReward
    UseAtrRegime = $UseAtrRegime; AtrRegimeBars = 50; AtrRegimeMult = 1.5
    ImpulseAtrMult = 1.25; BodyAtrMult = 0.65; SlowMaxAtr = $SlowMaxAtr
    UseGuard = "true"; BeTriggerR = $BeTriggerR; TrailStartR = $TrailStartR; TrailDistR = $TrailDistR
    SimCommission = "false"; CommissionPerLot = 0; SlZoneMult = $SlZoneMult
  }
  if ($SkipCompile) { & $run @args -SkipCompile } else { & $run @args }
  if ($LASTEXITCODE -ne 0) { throw "failed $Name exit=$LASTEXITCODE" }
  Add-Row -SumPath (Join-Path $tester ("last_summary_YorickSoS_{0}.txt" -f $Name)) -Name $Name -Notes $Notes -Deposit $Deposit
}

Run-One -Name "pustH_base" -Notes "H4 video risk2"
Run-One -Name "pustH_slow08" -Notes "slow0.8" -SlowMaxAtr 0.8 -SkipCompile
Run-One -Name "pustH_slow12" -Notes "slow1.2" -SlowMaxAtr 1.2 -SkipCompile
Run-One -Name "pustH_slow15" -Notes "slow1.5" -SlowMaxAtr 1.5 -SkipCompile
Run-One -Name "pustH_soff" -Notes "slow OFF" -RequireSlow "false" -SkipCompile
Run-One -Name "pustH_slx15" -Notes "slx1.5" -SlZoneMult 1.5 -SkipCompile
Run-One -Name "pustH_slx25" -Notes "slx2.5" -SlZoneMult 2.5 -SkipCompile
Run-One -Name "pustH_slx30" -Notes "slx3.0" -SlZoneMult 3.0 -SkipCompile
Run-One -Name "pustH_atroff" -Notes "atr OFF" -UseAtrRegime "false" -SkipCompile
Run-One -Name "pustH_guard05" -Notes "guard 0.5R" -BeTriggerR 0.5 -TrailStartR 0.5 -TrailDistR 0.5 -SkipCompile
Run-One -Name "pustH_zh1" -Notes "zones H4,H1" -ZoneTFs "H4,H1" -SkipCompile
Run-One -Name "pustH_rr15" -Notes "minRR1.5" -RequireMinRr "true" -MinRiskReward 1.5 -SkipCompile
Run-One -Name "pustH_slow12_slx25" -Notes "slow1.2+slx2.5" -SlowMaxAtr 1.2 -SlZoneMult 2.5 -SkipCompile
Run-One -Name "pustH_base_200" -Notes "H4 base $200" -Deposit 200 -SkipCompile

Write-Host ""
Write-Host "======== CSV ========"
Get-Content $csv
