$ErrorActionPreference = "Stop"
$tester = $PSScriptRoot
$run = Join-Path $tester "run_backtest.ps1"
$csv = Join-Path $tester "health_tune_guard.csv"

function Run-Guard {
  param(
    [string]$Name,
    [string]$UseGuard,
    [double]$Be = 0.5,
    [double]$Ts = 0.5,
    [double]$Td = 0.5,
    [switch]$SkipCompile
  )
  Write-Host ""
  Write-Host ("======== {0} guard={1} be={2} ts={3} td={4} ========" -f $Name, $UseGuard, $Be, $Ts, $Td)
  if ($SkipCompile) {
    & $run -Symbol "XAUUSD_Exness" -Period "M5" -TrendTF "H4" -ZoneTFs "M5,M15" -OnePosPerTf "false" `
      -FromDate "2021.01.01" -ToDate "2025.07.15" -Deposit 100000 -Model 4 -TimeoutSec 7200 `
      -ReportName ("YorickSoS_{0}" -f $Name) -RiskPct 0.5 `
      -RequireBos "true" -RequireFvg "true" -RequireTrend "true" `
      -RequireSlow "true" -RequireMinRr "false" -MinRiskReward 2.5 `
      -UseGuard $UseGuard -BeTriggerR $Be -TrailStartR $Ts -TrailDistR $Td `
      -SimCommission "true" -CommissionPerLot 3.5 -SlZoneMult 2.0 -SkipCompile
  } else {
    & $run -Symbol "XAUUSD_Exness" -Period "M5" -TrendTF "H4" -ZoneTFs "M5,M15" -OnePosPerTf "false" `
      -FromDate "2021.01.01" -ToDate "2025.07.15" -Deposit 100000 -Model 4 -TimeoutSec 7200 `
      -ReportName ("YorickSoS_{0}" -f $Name) -RiskPct 0.5 `
      -RequireBos "true" -RequireFvg "true" -RequireTrend "true" `
      -RequireSlow "true" -RequireMinRr "false" -MinRiskReward 2.5 `
      -UseGuard $UseGuard -BeTriggerR $Be -TrailStartR $Ts -TrailDistR $Td `
      -SimCommission "true" -CommissionPerLot 3.5 -SlZoneMult 2.0
  }
  $sum = Join-Path $tester ("last_summary_YorickSoS_{0}.txt" -f $Name)
  $txt = Get-Content $sum -Raw
  $net = if ($txt -match "Total Net Profit:\s*(.+)") { $Matches[1].Trim() } else { "?" }
  $pf  = if ($txt -match "Profit Factor:\s*(.+)") { $Matches[1].Trim() } else { "?" }
  $dd  = if ($txt -match "Equity DD Maximal:\s*(.+)") { $Matches[1].Trim() } else { "?" }
  $tr  = if ($txt -match "Total Trades:\s*(.+)") { $Matches[1].Trim() } else { "?" }
  $wr  = if ($txt -match "Profit Trades:\s*(.+)") { $Matches[1].Trim() } else { "?" }
  $line = ('"{0}","{1}","{2}","{3}","{4}","{5}","{6}","{7}","{8}","{9}"' -f $Name, $UseGuard, $Be, $Ts, $Td, $net, $pf, $dd, $tr, $wr)
  Add-Content -Path $csv -Value $line -Encoding ASCII
  Write-Host ("ROW " + $line)
}

Set-Content -Path $csv -Value "Preset,Guard,BeR,TrailStartR,TrailDistR,Net,PF,EquityDD,Trades,WinRate" -Encoding ASCII
Run-Guard -Name "guard_off" -UseGuard "false"
Run-Guard -Name "guard_g025" -UseGuard "true" -Be 0.25 -Ts 0.25 -Td 0.25 -SkipCompile
Run-Guard -Name "guard_g03" -UseGuard "true" -Be 0.3 -Ts 0.3 -Td 0.3 -SkipCompile
Run-Guard -Name "guard_g05" -UseGuard "true" -Be 0.5 -Ts 0.5 -Td 0.5 -SkipCompile
Run-Guard -Name "guard_g05t025" -UseGuard "true" -Be 0.5 -Ts 0.5 -Td 0.25 -SkipCompile
Run-Guard -Name "guard_g05t075" -UseGuard "true" -Be 0.5 -Ts 0.5 -Td 0.75 -SkipCompile
Run-Guard -Name "guard_be05_t1" -UseGuard "true" -Be 0.5 -Ts 1.0 -Td 0.5 -SkipCompile
Run-Guard -Name "guard_g1" -UseGuard "true" -Be 1.0 -Ts 1.0 -Td 0.5 -SkipCompile
Run-Guard -Name "guard_be03_t05" -UseGuard "true" -Be 0.3 -Ts 0.5 -Td 0.5 -SkipCompile
Write-Host ""
Get-Content $csv
