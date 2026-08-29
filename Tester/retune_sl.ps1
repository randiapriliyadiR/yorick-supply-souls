$ErrorActionPreference = "Stop"
$tester = $PSScriptRoot
$run = Join-Path $tester "run_backtest.ps1"
$csv = Join-Path $tester "health_tune_sl.csv"

function Run-Slx {
  param([double]$Slx, [switch]$SkipCompile)
  $name = "slx_" + ($Slx.ToString().Replace(".","p"))
  Write-Host ""
  Write-Host ("======== SlZoneMult={0} ========" -f $Slx)
  if ($SkipCompile) {
    & $run -Symbol "XAUUSD_Exness" -Period "M5" -TrendTF "H4" -ZoneTFs "M5,M15" -OnePosPerTf "false" `
      -FromDate "2021.01.01" -ToDate "2025.07.15" -Deposit 100000 -Model 4 -TimeoutSec 7200 `
      -ReportName ("YorickSoS_{0}" -f $name) -RiskPct 0.5 `
      -RequireBos "true" -RequireFvg "true" -RequireTrend "true" `
      -RequireSlow "true" -RequireMinRr "false" -MinRiskReward 2.5 `
      -UseGuard "true" -BeTriggerR 0.5 -TrailStartR 0.5 -TrailDistR 0.5 `
      -SimCommission "true" -CommissionPerLot 3.5 -SlZoneMult $Slx -SkipCompile
  } else {
    & $run -Symbol "XAUUSD_Exness" -Period "M5" -TrendTF "H4" -ZoneTFs "M5,M15" -OnePosPerTf "false" `
      -FromDate "2021.01.01" -ToDate "2025.07.15" -Deposit 100000 -Model 4 -TimeoutSec 7200 `
      -ReportName ("YorickSoS_{0}" -f $name) -RiskPct 0.5 `
      -RequireBos "true" -RequireFvg "true" -RequireTrend "true" `
      -RequireSlow "true" -RequireMinRr "false" -MinRiskReward 2.5 `
      -UseGuard "true" -BeTriggerR 0.5 -TrailStartR 0.5 -TrailDistR 0.5 `
      -SimCommission "true" -CommissionPerLot 3.5 -SlZoneMult $Slx
  }
  $sum = Join-Path $tester ("last_summary_YorickSoS_{0}.txt" -f $name)
  $txt = Get-Content $sum -Raw
  $net = if ($txt -match "Total Net Profit:\s*(.+)") { $Matches[1].Trim() } else { "?" }
  $pf  = if ($txt -match "Profit Factor:\s*(.+)") { $Matches[1].Trim() } else { "?" }
  $dd  = if ($txt -match "Equity DD Maximal:\s*(.+)") { $Matches[1].Trim() } else { "?" }
  $tr  = if ($txt -match "Total Trades:\s*(.+)") { $Matches[1].Trim() } else { "?" }
  $wr  = if ($txt -match "Profit Trades:\s*(.+)") { $Matches[1].Trim() } else { "?" }
  $line = ('"{0}","{1}","{2}","{3}","{4}","{5}"' -f $Slx, $net, $pf, $dd, $tr, $wr)
  Add-Content -Path $csv -Value $line -Encoding ASCII
  Write-Host ("ROW " + $line)
}

Set-Content -Path $csv -Value "SlZoneMult,Net,PF,EquityDD,Trades,WinRate" -Encoding ASCII
Run-Slx -Slx 1.0
Run-Slx -Slx 1.25 -SkipCompile
Run-Slx -Slx 1.5 -SkipCompile
Run-Slx -Slx 1.75 -SkipCompile
Run-Slx -Slx 2.0 -SkipCompile
Run-Slx -Slx 2.5 -SkipCompile
Write-Host ""
Get-Content $csv
