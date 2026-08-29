$ErrorActionPreference = "Stop"
$tester = $PSScriptRoot
$run = Join-Path $tester "run_backtest.ps1"
$csv = Join-Path $tester "health_tune_trend.csv"
Set-Content -Path $csv -Value "Preset,TrendTF,OnZoneTf,Net,PF,EquityDD,Trades,WinRate" -Encoding ASCII

function Run-Trend {
  param([string]$Name, [string]$TrendTF, [string]$OnZone, [switch]$SkipCompile)
  Write-Host ""
  Write-Host ("======== {0} ========" -f $Name)
  if ($SkipCompile) {
    & $run -Symbol "XAUUSD_Exness" -Period "M5" -TrendTF $TrendTF -TrendOnZoneTf $OnZone `
      -ZoneTFs "M5,M15" -OnePosPerTf "false" `
      -FromDate "2021.01.01" -ToDate "2025.07.15" -Deposit 100000 -Model 4 -TimeoutSec 7200 `
      -ReportName ("YorickSoS_{0}" -f $Name) -RiskPct 0.5 `
      -RequireBos "true" -RequireFvg "true" -RequireTrend "true" `
      -RequireSlow "true" -RequireMinRr "false" -MinRiskReward 2.5 `
      -UseGuard "true" -BeTriggerR 0.5 -TrailStartR 0.5 -TrailDistR 0.5 `
      -SimCommission "true" -CommissionPerLot 3.5 -SlZoneMult 2.0 -SkipCompile
  } else {
    & $run -Symbol "XAUUSD_Exness" -Period "M5" -TrendTF $TrendTF -TrendOnZoneTf $OnZone `
      -ZoneTFs "M5,M15" -OnePosPerTf "false" `
      -FromDate "2021.01.01" -ToDate "2025.07.15" -Deposit 100000 -Model 4 -TimeoutSec 7200 `
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
  $line = ('"{0}","{1}","{2}","{3}","{4}","{5}","{6}","{7}"' -f $Name, $TrendTF, $OnZone, $net, $pf, $dd, $tr, $wr)
  Add-Content -Path $csv -Value $line -Encoding ASCII
  Write-Host ("ROW " + $line)
}

Run-Trend -Name "trend_h4" -TrendTF "H4" -OnZone "false"
Run-Trend -Name "trend_zone" -TrendTF "H4" -OnZone "true" -SkipCompile
Run-Trend -Name "trend_m5" -TrendTF "M5" -OnZone "false" -SkipCompile
Run-Trend -Name "trend_m15" -TrendTF "M15" -OnZone "false" -SkipCompile
Run-Trend -Name "trend_h1" -TrendTF "H1" -OnZone "false" -SkipCompile

Write-Host ""
Get-Content $csv
