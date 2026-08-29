#Requires -Version 5.1
param(
  [Parameter(Mandatory)][double]$Deposit,
  [Parameter(Mandatory)][string[]]$TradeDirs,
  [string[]]$LegIds = @()
)
$ErrorActionPreference = "Stop"
function Get-TradeFiles([string]$Dir) {
  Get-ChildItem -LiteralPath $Dir -Filter "*.json" | Where-Object { $_.Name -match '^\d{4}-\d{2}\.json$' } | Sort-Object Name
}
function Read-Trades([string]$Dir, [string]$LegId) {
  $list = New-Object System.Collections.Generic.List[object]
  foreach ($f in Get-TradeFiles $Dir) {
    $json = Get-Content -LiteralPath $f.FullName -Raw | ConvertFrom-Json
    foreach ($t in @($json.trades)) {
      $list.Add([pscustomobject]@{
        legId=$LegId; id=$t.id; side=$t.side; volume=[double]$t.volume
        openTime=$t.openTime; closeTime=$t.closeTime
        openPrice=[double]$t.openPrice; closePrice=[double]$t.closePrice
        profit=[double]$t.profit; balance=[double]$t.balance; comment=$t.comment
      })
    }
  }
  return $list
}
function Merge-Legs {
  param([double]$Deposit, [object[]]$Trades)
  $byLeg = @{}
  foreach ($t in $Trades) {
    if (-not $byLeg.ContainsKey($t.legId)) { $byLeg[$t.legId] = New-Object System.Collections.Generic.List[object] }
    $byLeg[$t.legId].Add($t)
  }
  foreach ($k in @($byLeg.Keys)) { $byLeg[$k] = @($byLeg[$k] | Sort-Object closeTime, id) }
  $soloBeforeMap = @{}
  foreach ($k in $byLeg.Keys) {
    $prevBal = $Deposit
    foreach ($t in $byLeg[$k]) {
      $key = "$($t.legId)|$($t.closeTime)|$($t.id)"
      $soloBeforeMap[$key] = $prevBal
      $prevBal = [math]::Round($prevBal + [double]$t.profit, 2)
    }
  }
  $ordered = @($Trades | Sort-Object closeTime, legId, id)
  $shared = $Deposit; $peak = $Deposit; $maxDdMoney = 0.0; $maxDdPct = 0.0
  $grossWin = 0.0; $grossLoss = 0.0; $wins = 0
  foreach ($t in $ordered) {
    $key = "$($t.legId)|$($t.closeTime)|$($t.id)"
    $soloBefore = [double]$soloBeforeMap[$key]
    $scale = if ($soloBefore -gt 0) { $shared / $soloBefore } else { 1.0 }
    $pnl = [math]::Round(([double]$t.profit) * $scale, 2)
    $shared = [math]::Round($shared + $pnl, 2)
    if ($shared -gt $peak) { $peak = $shared }
    $dd = $peak - $shared
    if ($dd -gt $maxDdMoney) {
      $maxDdMoney = $dd
      $maxDdPct = if ($peak -gt 0) { 100.0 * $dd / $peak } else { 0.0 }
    }
    if ($pnl -gt 0) { $grossWin += $pnl; $wins++ } elseif ($pnl -lt 0) { $grossLoss += -$pnl }
  }
  $net = [math]::Round($shared - $Deposit, 2)
  $pf = if ($grossLoss -gt 0) { [math]::Round($grossWin / $grossLoss, 2) } elseif ($grossWin -gt 0) { 999.0 } else { 0.0 }
  $n = $ordered.Count
  $wr = if ($n -gt 0) { [math]::Round(100.0 * $wins / $n, 2) } else { 0.0 }
  $ret = [math]::Round(100.0 * $net / $Deposit, 1)
  Write-Host ("Deposit={0} Net={1} Return={2}% PF={3} DD={4} ({5}%) Trades={6} Wins={7} WinRate={8}%" -f $Deposit, $net, $ret, $pf, ([math]::Round($maxDdMoney,2)), ([math]::Round($maxDdPct,2)), $n, $wins, $wr)
}
$all = New-Object System.Collections.Generic.List[object]
for ($i = 0; $i -lt $TradeDirs.Count; $i++) {
  $id = if ($i -lt $LegIds.Count -and $LegIds[$i]) { $LegIds[$i] } else { "leg$i" }
  foreach ($t in Read-Trades -Dir $TradeDirs[$i] -LegId $id) { $all.Add($t) }
}
Merge-Legs -Deposit $Deposit -Trades $all.ToArray()
