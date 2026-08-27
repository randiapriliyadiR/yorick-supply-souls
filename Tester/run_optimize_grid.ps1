<#
.SYNOPSIS
  Coarse then refine grid search for Yorick SoS on XAUUSD D1 deposit 100000.
#>
param(
  [double]$MaxDdPct = 40.0,
  [string]$OutCsv = ""
)

$ErrorActionPreference = "Stop"
$Runner = Join-Path $PSScriptRoot "run_backtest.ps1"
if (-not $OutCsv) {
  $OutCsv = Join-Path $PSScriptRoot "optimize_grid_results.csv"
}

function Parse-Money([string]$s) {
  if ([string]::IsNullOrWhiteSpace($s) -or $s -eq "n/a") { return 0.0 }
  $t = ($s -replace "[^\d\.\-\+]", "")
  if ($t -eq "" -or $t -eq "-" -or $t -eq "+") { return 0.0 }
  return [double]::Parse($t, [System.Globalization.CultureInfo]::InvariantCulture)
}

function Parse-DdPct([string]$s) {
  if ($s -match "\(([\d\.]+)%\)") {
    return [double]::Parse($Matches[1], [System.Globalization.CultureInfo]::InvariantCulture)
  }
  return 999.0
}

function BoolTag([string]$b) {
  if ($b -eq "true") { return "1" }
  return "0"
}

function Invoke-One(
  [double]$impulse,
  [double]$body,
  [string]$fvg,
  [string]$slow,
  [double]$slowMax,
  [double]$slx,
  [double]$risk,
  [bool]$skipCompile
) {
  $inv = [System.Globalization.CultureInfo]::InvariantCulture
  $iTag = $impulse.ToString("0.00", $inv).Replace(".", "p")
  $bTag = $body.ToString("0.00", $inv).Replace(".", "p")
  $mTag = $slowMax.ToString("0.00", $inv).Replace(".", "p")
  $xTag = $slx.ToString("0.0", $inv).Replace(".", "p")
  $rTag = $risk.ToString("0.0", $inv).Replace(".", "p")
  $tag = "opt_I${iTag}_B${bTag}_F$(BoolTag $fvg)_S$(BoolTag $slow)_M${mTag}_X${xTag}_R${rTag}"
  $argList = @(
    "-NoProfile", "-ExecutionPolicy", "Bypass",
    "-File", $Runner,
    "-Symbol", "XAUUSD",
    "-Period", "D1",
    "-Deposit", "100000",
    "-ImpulseAtrMult", $impulse.ToString($inv),
    "-BodyAtrMult", $body.ToString($inv),
    "-RequireBos", "true",
    "-RequireFvg", $fvg,
    "-RequireSlow", $slow,
    "-SlowMaxAtr", $slowMax.ToString($inv),
    "-SlZoneMult", $slx.ToString($inv),
    "-RiskPct", $risk.ToString($inv),
    "-ReportName", $tag,
    "-TimeoutSec", "900"
  )
  if ($skipCompile) { $argList += "-SkipCompile" }
  & powershell @argList
  if ($LASTEXITCODE -ne 0) { throw "run_backtest failed for $tag exit=$LASTEXITCODE" }
  $sumPath = Join-Path $PSScriptRoot ("last_summary_{0}.txt" -f $tag)
  $text = Get-Content $sumPath -Raw
  $net = 0.0; $pf = 0.0; $trades = 0; $dd = 999.0
  if ($text -match "Total Net Profit:\s*(.+)") { $net = Parse-Money $Matches[1].Trim() }
  if ($text -match "Profit Factor:\s*(.+)") { $pf = Parse-Money $Matches[1].Trim() }
  if ($text -match "Total Trades:\s*(.+)") { $trades = [int](Parse-Money $Matches[1].Trim()) }
  if ($text -match "Equity DD Maximal:\s*(.+)") { $dd = Parse-DdPct $Matches[1].Trim() }
  $score = $net
  if ($dd -gt $MaxDdPct) { $score = $net - (($dd - $MaxDdPct) * 2000.0) }
  if ($trades -lt 10) { $score = $score - ((10 - $trades) * 1500.0) }
  return [pscustomobject]@{
    Impulse = $impulse; Body = $body; Fvg = $fvg; Slow = $slow
    SlowMax = $slowMax; Slx = $slx; Risk = $risk
    Net = $net; PF = $pf; Trades = $trades; DdPct = $dd; Score = $score; Tag = $tag
  }
}

Write-Host "== Compile once =="
$null = Invoke-One 1.5 0.8 "true" "true" 0.8 2.0 2.0 $false

$phase1 = New-Object System.Collections.Generic.List[object]
$imps = @(1.0, 1.25, 1.5, 2.0)
$bodies = @(0.5, 0.8)
$fvgs = @("true", "false")
$slows = @("true", "false")
$i = 0
$total = $imps.Count * $bodies.Count * $fvgs.Count * $slows.Count
Write-Host ("== Phase 1 coarse grid ({0} runs) ==" -f $total)
foreach ($imp in $imps) {
  foreach ($body in $bodies) {
    foreach ($fvg in $fvgs) {
      foreach ($slow in $slows) {
        $i++
        Write-Host ("--- [{0}/{1}] Imp={2} Body={3} Fvg={4} Slow={5} ---" -f $i, $total, $imp, $body, $fvg, $slow)
        [void]$phase1.Add((Invoke-One $imp $body $fvg $slow 0.8 2.0 2.0 $true))
      }
    }
  }
}

$phase1 | Sort-Object Score -Descending | Export-Csv -Path $OutCsv -NoTypeInformation -Encoding UTF8
$best = $phase1 | Sort-Object Score -Descending | Select-Object -First 1
Write-Host ("Phase1 best: Imp={0} Body={1} Fvg={2} Slow={3} Net={4} DD={5}% Trades={6} Score={7}" -f `
  $best.Impulse, $best.Body, $best.Fvg, $best.Slow, $best.Net, $best.DdPct, $best.Trades, $best.Score)

$i0 = [double]$best.Impulse
$b0 = [double]$best.Body
$imps2 = @([Math]::Round($i0 - 0.25, 2), $i0, [Math]::Round($i0 + 0.25, 2)) | Where-Object { $_ -ge 0.75 } | Select-Object -Unique
$bodies2 = @([Math]::Round($b0 - 0.15, 2), $b0, [Math]::Round($b0 + 0.15, 2)) | Where-Object { $_ -ge 0.3 } | Select-Object -Unique
$slowMaxs = @([double]$best.SlowMax)
$slxs = @(1.5, 2.0, 2.5)

$phase2 = New-Object System.Collections.Generic.List[object]
$combos = New-Object System.Collections.Generic.List[object]
foreach ($imp in $imps2) {
  foreach ($body in $bodies2) {
    foreach ($sx in $slxs) {
      [void]$combos.Add(@($imp, $body, [double]$best.SlowMax, $sx))
    }
  }
}
if ($best.Slow -eq "true") {
  foreach ($sm in @(0.6, 0.8, 1.0, 1.2)) {
    if ([Math]::Abs($sm - [double]$best.SlowMax) -lt 1e-9) { continue }
    [void]$combos.Add(@($i0, $b0, $sm, 2.0))
  }
}
Write-Host ("== Phase 2 refine ({0} runs) ==" -f $combos.Count)
$j = 0
foreach ($c in $combos) {
  $j++
  Write-Host ("--- refine [{0}/{1}] Imp={2} Body={3} SlowMax={4} Slx={5} ---" -f `
    $j, $combos.Count, $c[0], $c[1], $c[2], $c[3])
  [void]$phase2.Add((Invoke-One ([double]$c[0]) ([double]$c[1]) ([string]$best.Fvg) ([string]$best.Slow) ([double]$c[2]) ([double]$c[3]) 2.0 $true))
}

$mid = @($phase1.ToArray() + $phase2.ToArray()) | Sort-Object Score -Descending | Select-Object -First 1
Write-Host ("Phase2 best: Imp={0} Body={1} Fvg={2} Slow={3} SlowMax={4} Slx={5} Net={6}" -f `
  $mid.Impulse, $mid.Body, $mid.Fvg, $mid.Slow, $mid.SlowMax, $mid.Slx, $mid.Net)

$phase3 = New-Object System.Collections.Generic.List[object]
Write-Host "== Phase 3 risk sweep =="
foreach ($r in @(1.0, 1.5, 2.0, 2.5, 3.0)) {
  Write-Host ("--- risk={0} ---" -f $r)
  [void]$phase3.Add((Invoke-One ([double]$mid.Impulse) ([double]$mid.Body) ([string]$mid.Fvg) ([string]$mid.Slow) ([double]$mid.SlowMax) ([double]$mid.Slx) $r $true))
}

$all = @($phase1.ToArray() + $phase2.ToArray() + $phase3.ToArray())
$all | Sort-Object Score -Descending | Export-Csv -Path $OutCsv -NoTypeInformation -Encoding UTF8
$winner = $all | Sort-Object Score -Descending | Select-Object -First 1
$winnerPath = Join-Path $PSScriptRoot "optimize_best.txt"
@(
  "Best score under MaxDdPct=$MaxDdPct",
  ("ImpulseAtrMult={0}" -f $winner.Impulse),
  ("BodyAtrMult={0}" -f $winner.Body),
  ("RequireFvg={0}" -f $winner.Fvg),
  ("RequireSlow={0}" -f $winner.Slow),
  ("SlowMaxAtr={0}" -f $winner.SlowMax),
  ("SlZoneMult={0}" -f $winner.Slx),
  ("RiskPct={0}" -f $winner.Risk),
  ("Net={0}" -f $winner.Net),
  ("PF={0}" -f $winner.PF),
  ("Trades={0}" -f $winner.Trades),
  ("DdPct={0}" -f $winner.DdPct),
  ("Score={0}" -f $winner.Score),
  ("Tag={0}" -f $winner.Tag)
) | Set-Content -Path $winnerPath -Encoding UTF8

Write-Host "==== WINNER ===="
Get-Content $winnerPath
Write-Host "CSV: $OutCsv"
