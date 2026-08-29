$ErrorActionPreference = "Stop"
$tester = $PSScriptRoot
$run = Join-Path $tester "run_backtest.ps1"
$csv = Join-Path $tester "health_tune_trend_d1_h4.csv"
Set-Content -Path $csv -Value "Preset,TrendTF,Zones,Deposit,Risk,Net,ReturnPct,PF,EquityDD,Trades,WinRate" -Encoding ASCII

function Run-One {
  param([string]$Name, [string]$TrendTF, [switch]$SkipCompile)
  Write-Host ""
  Write-Host ("======== {0} ========" -f $Name)
  if ($SkipCompile) {
    & $run -Symbol "XAUUSD_Exness" -Period "M5" -TrendTF $TrendTF -TrendOnZoneTf "false" `
      -ZoneTFs "M5,M15,M30,H1" -OnePosPerTf "false" `
      -FromDate "2021.01.01" -ToDate "2025.07.15" -Deposit 200 -Model 4 -TimeoutSec 7200 `
      -ReportName ("YorickSoS_{0}" -f $Name) -RiskPct 0.5 `
      -RequireBos "true" -RequireFvg "true" -RequireTrend "true" `
      -RequireSlow "true" -RequireMinRr "false" -MinRiskReward 2.5 `
      -UseGuard "true" -BeTriggerR 0.5 -TrailStartR 0.5 -TrailDistR 0.5 `
      -SimCommission "true" -CommissionPerLot 3.5 -SlZoneMult 2.0 -SkipCompile
  } else {
    & $run -Symbol "XAUUSD_Exness" -Period "M5" -TrendTF $TrendTF -TrendOnZoneTf "false" `
      -ZoneTFs "M5,M15,M30,H1" -OnePosPerTf "false" `
      -FromDate "2021.01.01" -ToDate "2025.07.15" -Deposit 200 -Model 4 -TimeoutSec 7200 `
      -ReportName ("YorickSoS_{0}" -f $Name) -RiskPct 0.5 `
      -RequireBos "true" -RequireFvg "true" -RequireTrend "true" `
      -RequireSlow "true" -RequireMinRr "false" -MinRiskReward 2.5 `
      -UseGuard "true" -BeTriggerR 0.5 -TrailStartR 0.5 -TrailDistR 0.5 `
      -SimCommission "true" -CommissionPerLot 3.5 -SlZoneMult 2.0
  }
  $sum = Join-Path $tester ("last_summary_YorickSoS_{0}.txt" -f $Name)
  $txt = Get-Content $sum -Raw
  $net = if ($txt -match "Total Net Profit:\s*(.+)") { $Matches[1].Trim() } else { "?" }
  $pf  = if ($txt -match "Profit Factor:\s*(.+)") { $Matches[1].Trim() } else { "?" }
  $dd  = if ($txt -match "Equity DD Maximal:\s*(.+)") { $Matches[1].Trim() } else { "?" }
  $tr  = if ($txt -match "Total Trades:\s*(.+)") { $Matches[1].Trim() } else { "?" }
  $wr  = if ($txt -match "Profit Trades:\s*(.+)") { $Matches[1].Trim() } else { "?" }
  $netNum = 0.0
  if ($net -match "-?[\d\s]+(?:[\.,]\d+)?") {
    $netNum = [double](($Matches[0] -replace "\s","").Replace(",", "."))
  }
  $ret = [math]::Round(100.0 * $netNum / 200.0, 1)
  $line = ('"{0}","{1}","M5,M15,M30,H1","200","0.5","{2}","{3}","{4}","{5}","{6}","{7}"' -f $Name, $TrendTF, $net, $ret, $pf, $dd, $tr, $wr)
  Add-Content -Path $csv -Value $line -Encoding ASCII
  Write-Host ("ROW " + $line)
}

# Also baseline: current M5,M15 + H4 at $200 for fair compare
Write-Host "======== baseline_m515_h4_200 ========"
& $run -Symbol "XAUUSD_Exness" -Period "M5" -TrendTF "H4" -TrendOnZoneTf "false" `
  -ZoneTFs "M5,M15" -OnePosPerTf "false" `
  -FromDate "2021.01.01" -ToDate "2025.07.15" -Deposit 200 -Model 4 -TimeoutSec 7200 `
  -ReportName "YorickSoS_baseline_m515_h4_200" -RiskPct 0.5 `
  -RequireBos "true" -RequireFvg "true" -RequireTrend "true" `
  -RequireSlow "true" -RequireMinRr "false" -MinRiskReward 2.5 `
  -UseGuard "true" -BeTriggerR 0.5 -TrailStartR 0.5 -TrailDistR 0.5 `
  -SimCommission "true" -CommissionPerLot 3.5 -SlZoneMult 2.0
$sum = Join-Path $tester "last_summary_YorickSoS_baseline_m515_h4_200.txt"
$txt = Get-Content $sum -Raw
$net = if ($txt -match "Total Net Profit:\s*(.+)") { $Matches[1].Trim() } else { "?" }
$pf  = if ($txt -match "Profit Factor:\s*(.+)") { $Matches[1].Trim() } else { "?" }
$dd  = if ($txt -match "Equity DD Maximal:\s*(.+)") { $Matches[1].Trim() } else { "?" }
$tr  = if ($txt -match "Total Trades:\s*(.+)") { $Matches[1].Trim() } else { "?" }
$wr  = if ($txt -match "Profit Trades:\s*(.+)") { $Matches[1].Trim() } else { "?" }
$netNum = 0.0
if ($net -match "-?[\d\s]+(?:[\.,]\d+)?") { $netNum = [double](($Matches[0] -replace "\s","").Replace(",", ".")) }
$ret = [math]::Round(100.0 * $netNum / 200.0, 1)
$line = ('"baseline_m515_h4_200","H4","M5,M15","200","0.5","{0}","{1}","{2}","{3}","{4}","{5}"' -f $net, $ret, $pf, $dd, $tr, $wr)
Add-Content -Path $csv -Value $line -Encoding ASCII
Write-Host ("ROW " + $line)

Run-One -Name "zones4_trend_h4_200" -TrendTF "H4" -SkipCompile
Run-One -Name "zones4_trend_d1_200" -TrendTF "D1" -SkipCompile

Write-Host ""
Get-Content $csv
