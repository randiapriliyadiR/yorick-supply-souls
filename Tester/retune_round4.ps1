$ErrorActionPreference = "Stop"
$tester = $PSScriptRoot
$run = Join-Path $tester "run_backtest.ps1"
$csv = Join-Path $tester "health_tune_round4.csv"

function Run-One {
  param(
    [string]$Name,
    [string]$ZoneTFs,
    [string]$OnePosPerTf,
    [double]$RiskPct,
    [string]$RequireSlow,
    [string]$RequireMinRr,
    [double]$MinRiskReward,
    [switch]$SkipCompile
  )
  $report = "YorickSoS_$Name"
  Write-Host ""
  Write-Host "======== $Name ========"
  if ($SkipCompile) {
    & $run -Symbol "XAUUSD_Exness" -Period "M5" -TrendTF "H4" `
      -ZoneTFs $ZoneTFs -OnePosPerTf $OnePosPerTf `
      -FromDate "2021.01.01" -ToDate "2025.07.15" `
      -Deposit 100000 -Model 4 -TimeoutSec 7200 `
      -ReportName $report -RiskPct $RiskPct `
      -RequireBos "true" -RequireFvg "true" -RequireTrend "true" `
      -RequireSlow $RequireSlow -RequireMinRr $RequireMinRr -MinRiskReward $MinRiskReward `
      -UseGuard "true" -BeTriggerR 0.5 -TrailStartR 0.5 -TrailDistR 0.5 `
      -SimCommission "true" -CommissionPerLot 3.5 -SlZoneMult 2.0 `
      -SkipCompile
  } else {
    & $run -Symbol "XAUUSD_Exness" -Period "M5" -TrendTF "H4" `
      -ZoneTFs $ZoneTFs -OnePosPerTf $OnePosPerTf `
      -FromDate "2021.01.01" -ToDate "2025.07.15" `
      -Deposit 100000 -Model 4 -TimeoutSec 7200 `
      -ReportName $report -RiskPct $RiskPct `
      -RequireBos "true" -RequireFvg "true" -RequireTrend "true" `
      -RequireSlow $RequireSlow -RequireMinRr $RequireMinRr -MinRiskReward $MinRiskReward `
      -UseGuard "true" -BeTriggerR 0.5 -TrailStartR 0.5 -TrailDistR 0.5 `
      -SimCommission "true" -CommissionPerLot 3.5 -SlZoneMult 2.0
  }

  $sum = Join-Path $tester ("last_summary_{0}.txt" -f $report)
  $txt = Get-Content $sum -Raw
  $net = if ($txt -match "Total Net Profit:\s*(.+)") { $Matches[1].Trim() } else { "?" }
  $pf  = if ($txt -match "Profit Factor:\s*(.+)") { $Matches[1].Trim() } else { "?" }
  $dd  = if ($txt -match "Equity DD Maximal:\s*(.+)") { $Matches[1].Trim() } else { "?" }
  $tr  = if ($txt -match "Total Trades:\s*(.+)") { $Matches[1].Trim() } else { "?" }
  $wr  = if ($txt -match "Profit Trades:\s*(.+)") { $Matches[1].Trim() } else { "?" }
  $line = '"' + $Name + '","' + $net + '","' + $pf + '","' + $dd + '","' + $tr + '","' + $wr + '"'
  Add-Content -Path $csv -Value $line -Encoding ASCII
  Write-Host ("ROW " + $line)
}

Set-Content -Path $csv -Value "Preset,Net,PF,EquityDD,Trades,WinRate" -Encoding ASCII

Run-One -Name "r4_rr15_s_m530_r05" -ZoneTFs "M5,M15,M30" -OnePosPerTf "true" -RiskPct 0.5 -RequireSlow "true" -RequireMinRr "true" -MinRiskReward 1.5
Run-One -Name "r4_rr20_s_m530_r05" -ZoneTFs "M5,M15,M30" -OnePosPerTf "true" -RiskPct 0.5 -RequireSlow "true" -RequireMinRr "true" -MinRiskReward 2.0 -SkipCompile
Run-One -Name "r4_rr15_s_m515_r05" -ZoneTFs "M5,M15" -OnePosPerTf "true" -RiskPct 0.5 -RequireSlow "true" -RequireMinRr "true" -MinRiskReward 1.5 -SkipCompile
Run-One -Name "r4_norr_s_m530_r05" -ZoneTFs "M5,M15,M30" -OnePosPerTf "true" -RiskPct 0.5 -RequireSlow "true" -RequireMinRr "false" -MinRiskReward 2.5 -SkipCompile
Run-One -Name "r4_rr15_nos_m530_r05" -ZoneTFs "M5,M15,M30" -OnePosPerTf "true" -RiskPct 0.5 -RequireSlow "false" -RequireMinRr "true" -MinRiskReward 1.5 -SkipCompile
Run-One -Name "r4_norr_nos_m530_r05" -ZoneTFs "M5,M15,M30" -OnePosPerTf "true" -RiskPct 0.5 -RequireSlow "false" -RequireMinRr "false" -MinRiskReward 2.5 -SkipCompile
Run-One -Name "r4_rr15_s_m530_r1" -ZoneTFs "M5,M15,M30" -OnePosPerTf "true" -RiskPct 1.0 -RequireSlow "true" -RequireMinRr "true" -MinRiskReward 1.5 -SkipCompile
Run-One -Name "r4_norr_s_m515_r05" -ZoneTFs "M5,M15" -OnePosPerTf "false" -RiskPct 0.5 -RequireSlow "true" -RequireMinRr "false" -MinRiskReward 2.5 -SkipCompile

Write-Host ""
Write-Host ("Done. CSV: " + $csv)
Get-Content $csv
