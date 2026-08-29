#Requires -Version 5.1
param(
  [Parameter(Mandatory)][string]$HtmlPath,
  [Parameter(Mandatory)][string]$StandId,
  [Parameter(Mandatory)][double]$Deposit,
  [string]$DocsData = "",
  [string]$Label = "",
  [string]$Period = "",
  [double]$Risk = 2,
  [string]$GuardLabel = "",
  [string]$ModelLabel = "Every tick based on real ticks",
  [string]$Broker = "XAUUSD_Exness (imported ticks)",
  [switch]$ReplaceCatalog
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Read-Mt5Html {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) { throw "HTML report not found: $Path" }
  $bytes = [IO.File]::ReadAllBytes($Path)
  if ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) {
    return [IO.File]::ReadAllText($Path, [Text.Encoding]::Unicode)
  }
  if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
    return [IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8)
  }
  return [IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8)
}

function Get-CellText {
  param([string]$Html)
  $t = [regex]::Replace($Html, '<[^>]+>', '')
  $t = [System.Net.WebUtility]::HtmlDecode($t)
  return $t.Trim()
}

function Parse-Mt5Number {
  param([string]$Text)
  if ([string]::IsNullOrWhiteSpace($Text)) { return 0.0 }
  $clean = $Text -replace '\s', '' -replace ',', '.'
  $clean = $clean -replace '\(([^)]+)\)', ''
  if ($clean -match '^-?\d+(\.\d+)?$') { return [double]$clean }
  if ($clean -match '-?\d+(?:\.\d+)?') { return [double]$Matches[0] }
  return 0.0
}

function Parse-Summary {
  param([string]$Html)
  function Get-Metric {
    param([string]$Label)
    $pattern = "(?s)<td[^>]*>\s*$([regex]::Escape($Label)):\s*</td>\s*<td[^>]*>\s*<b>([^<]+)</b>"
    $m = [regex]::Match($Html, $pattern)
    if (-not $m.Success) { return $null }
    return $m.Groups[1].Value.Trim()
  }
  $net = Parse-Mt5Number (Get-Metric "Total Net Profit")
  $pf = Parse-Mt5Number (Get-Metric "Profit Factor")
  $totalTrades = [int](Parse-Mt5Number (Get-Metric "Total Trades"))
  $equityDdRaw = Get-Metric "Equity Drawdown Maximal"
  $equityDdPct = 0.0
  $equityDdMoney = 0.0
  if ($equityDdRaw -match '^\s*([\d\s.,]+)\s*\(([\d.,\s]+)%\)') {
    $equityDdMoney = Parse-Mt5Number $Matches[1]
    $equityDdPct = Parse-Mt5Number $Matches[2]
  } elseif ($equityDdRaw -match '\(([\d.,\s]+)%\)') {
    $equityDdPct = Parse-Mt5Number $Matches[1]
  }
  $profitTradesRaw = Get-Metric "Profit Trades (% of total)"
  $winRate = if ($profitTradesRaw) { $profitTradesRaw } else { "" }
  $symbol = "XAUUSD"
  $symMatch = [regex]::Match($Html, '(?s)<td[^>]*>\s*Symbol:\s*</td>\s*<td[^>]*>\s*<b>([^<]+)</b>')
  if ($symMatch.Success) { $symbol = $symMatch.Groups[1].Value.Trim() }
  $from = "2021.01.01"; $to = "2026.08.26"
  $periodMatch = [regex]::Match($Html, '(?s)<td[^>]*>\s*Period:\s*</td>\s*<td[^>]*>\s*<b>[^(\(]*\(([^)]+)\)</b>')
  if ($periodMatch.Success) {
    $range = $periodMatch.Groups[1].Value.Trim()
    if ($range -match '(\d{4}\.\d{2}\.\d{2})\s*-\s*(\d{4}\.\d{2}\.\d{2})') { $from = $Matches[1]; $to = $Matches[2] }
  }
  return [pscustomobject]@{
    net=$net; profitFactor=$pf; equityDdPct=$equityDdPct; equityDdMoney=$equityDdMoney
    totalTrades=$totalTrades; winRate=$winRate; symbol=$symbol; from=$from; to=$to
  }
}

function Get-DailyDrawdown {
  param([System.Collections.Generic.List[object]]$Trades, [double]$Deposit)
  $prevBal = $Deposit
  $day = $null
  $dayPeak = $Deposit
  $maxDaily = 0.0
  $maxDailyPct = 0.0
  foreach ($t in $Trades) {
    $d = if ($t.closeTime -match '^(\d{4}\.\d{2}\.\d{2})') { $Matches[1] } else { "" }
    $bal = [double]$t.balance
    if ($d -ne $day) {
      $day = $d
      $dayPeak = $prevBal
    }
    if ($bal -gt $dayPeak) { $dayPeak = $bal }
    $ddd = $dayPeak - $bal
    if ($ddd -gt $maxDaily -and $dayPeak -gt 0) {
      $maxDaily = $ddd
      $maxDailyPct = 100.0 * $ddd / $dayPeak
    }
    $prevBal = $bal
  }
  return [pscustomobject]@{
    money = [math]::Round($maxDaily, 2)
    pct = [math]::Round($maxDailyPct, 2)
  }
}

function Parse-DealsTable {
  param([string]$Html)
  $headerIdx = $Html.IndexOf('<b>Deals</b>')
  if ($headerIdx -lt 0) { throw "Deals table not found in report" }
  $slice = $Html.Substring($headerIdx)
  $endIdx = $slice.IndexOf('</table>')
  if ($endIdx -lt 0) { throw "Deals table end not found" }
  $tableHtml = $slice.Substring(0, $endIdx)
  $rows = [regex]::Matches($tableHtml, '(?is)<tr[^>]*>(.*?)</tr>')
  $deals = New-Object System.Collections.Generic.List[object]
  $headerSeen = $false
  foreach ($row in $rows) {
    $cells = [regex]::Matches($row.Groups[1].Value, '(?is)<td[^>]*>(.*?)</td>')
    if ($cells.Count -lt 11) { continue }
    $values = foreach ($c in $cells) { Get-CellText $c.Groups[1].Value }
    if ($values[0] -eq 'Time') { $headerSeen = $true; continue }
    if (-not $headerSeen) { continue }
    $type = $values[3].ToLower()
    if ($type -eq 'balance') { continue }
    $deals.Add([pscustomobject]@{
      time=$values[0]; deal=[int](Parse-Mt5Number $values[1]); symbol=$values[2]; type=$type; direction=$values[4].ToLower()
      volume=Parse-Mt5Number $values[5]; price=Parse-Mt5Number $values[6]; order=[int](Parse-Mt5Number $values[7])
      commission=Parse-Mt5Number $values[8]; swap=Parse-Mt5Number $values[9]; profit=Parse-Mt5Number $values[10]
      balance= if ($cells.Count -ge 12) { Parse-Mt5Number (Get-CellText $cells[11].Groups[1].Value) } else { 0.0 }
      comment= if ($cells.Count -ge 13) { Get-CellText $cells[12].Groups[1].Value } else { "" }
    })
  }
  return $deals
}

function Build-TradesFromDeals {
  param([System.Collections.Generic.List[object]]$Deals, [double]$Deposit)
  $longOpen = New-Object System.Collections.Generic.List[object]
  $shortOpen = New-Object System.Collections.Generic.List[object]
  $trades = New-Object System.Collections.Generic.List[object]
  $balance = $Deposit
  foreach ($d in $Deals) {
    if ($d.direction -eq 'in') {
      if ($d.type -eq 'buy') { $longOpen.Add($d) }
      elseif ($d.type -eq 'sell') { $shortOpen.Add($d) }
      continue
    }
    if ($d.direction -ne 'out') { continue }
    $entry = $null
    if ($d.type -eq 'sell') {
      if ($longOpen.Count -eq 0) { throw "Unmatched sell-out deal $($d.deal) at $($d.time)" }
      $entry = $longOpen[0]; $longOpen.RemoveAt(0)
    } elseif ($d.type -eq 'buy') {
      if ($shortOpen.Count -eq 0) { throw "Unmatched buy-out deal $($d.deal) at $($d.time)" }
      $entry = $shortOpen[0]; $shortOpen.RemoveAt(0)
    } else { continue }
    $netProfit = $d.profit + $d.commission + $d.swap
    $balance += $netProfit
    $balanceRounded = [math]::Round($balance, 2)
    if ($d.balance -gt 0 -and [math]::Abs($d.balance - $balanceRounded) -gt 0.02) {
      Write-Warning "Balance drift at deal $($d.deal): computed $balanceRounded vs report $($d.balance)"
    }
    $side = if ($entry.type -eq 'buy') { 'buy' } else { 'sell' }
    $trades.Add([pscustomobject]@{
      id=$d.order; side=$side; volume=$entry.volume; openTime=$entry.time; closeTime=$d.time
      openPrice=$entry.price; closePrice=$d.price; profit=[math]::Round($netProfit, 2); balance=$balanceRounded
      comment=$entry.comment; commission=[math]::Round($d.commission, 2); swap=[math]::Round($d.swap, 2)
    })
  }
  if ($longOpen.Count -gt 0 -or $shortOpen.Count -gt 0) { throw "Unclosed positions remain: long=$($longOpen.Count) short=$($shortOpen.Count)" }
  return $trades
}

function Get-CloseMonth {
  param([string]$CloseTime)
  if ($CloseTime -match '^(\d{4})\.(\d{2})\.') { return "$($Matches[1])-$($Matches[2])" }
  throw "Invalid closeTime format: $CloseTime"
}

function Write-JsonFile {
  param([string]$Path, $Object)
  $dir = Split-Path -Parent $Path
  if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  $json = $Object | ConvertTo-Json -Depth 20 -Compress:$false
  [IO.File]::WriteAllText($Path, $json, [Text.UTF8Encoding]::new($false))
}

function Convert-TradeSummary {
  param($Trade)
  if ($null -eq $Trade) { return $null }
  return [ordered]@{
    id = $Trade.id
    side = $Trade.side
    volume = $Trade.volume
    openTime = $Trade.openTime
    closeTime = $Trade.closeTime
    openPrice = $Trade.openPrice
    closePrice = $Trade.closePrice
    profit = $Trade.profit
    balance = $Trade.balance
    comment = $Trade.comment
    commission = $Trade.commission
    swap = $Trade.swap
  }
}

function Update-StandsJson {
  param([string]$StandsPath, [string]$StandId, [hashtable]$StandEntry, [bool]$ReplaceCatalog)
  # Round-trip through JSON so nested trade extremes survive PSCustomObject casts.
  $entryObj = ($StandEntry | ConvertTo-Json -Depth 20 | ConvertFrom-Json)
  if ((-not $ReplaceCatalog) -and (Test-Path -LiteralPath $StandsPath)) {
    $catalog = Get-Content -LiteralPath $StandsPath -Raw -Encoding UTF8 | ConvertFrom-Json
  } else {
    $catalog = [pscustomobject]@{ version="1.15.0"; updated=(Get-Date -Format "yyyy-MM-dd"); defaultStand=$StandId; stands=@() }
  }
  $standsList = [System.Collections.Generic.List[object]]@()
  $found = $false
  foreach ($s in @($catalog.stands)) {
    if ($null -eq $s) { continue }
    if ($s.id -eq $StandId) { $standsList.Add($entryObj); $found = $true }
    else { $standsList.Add($s) }
  }
  if (-not $found) { $standsList.Add($entryObj) }
  $out = [pscustomobject]@{
    version="1.15.0"; updated=(Get-Date -Format "yyyy-MM-dd")
    defaultStand= if ($ReplaceCatalog) { $StandId } elseif ($catalog.defaultStand) { $catalog.defaultStand } else { $StandId }
    stands=@($standsList)
  }
  Write-JsonFile -Path $StandsPath -Object $out
}

$repoRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($DocsData)) { $DocsData = Join-Path $repoRoot "docs\data" }
$html = Read-Mt5Html -Path $HtmlPath
$summary = Parse-Summary -Html $html
$deals = Parse-DealsTable -Html $html
$trades = Build-TradesFromDeals -Deals $deals -Deposit $Deposit
if ($trades.Count -ne $summary.totalTrades) { Write-Warning "Trade count mismatch: parsed $($trades.Count) vs summary $($summary.totalTrades)" }
$standDir = Join-Path $DocsData $StandId
$tradesOutDir = Join-Path $standDir "trades"
if (Test-Path $tradesOutDir) { Remove-Item -LiteralPath $tradesOutDir -Recurse -Force }

$tradesDir = Join-Path $standDir "trades"
New-Item -ItemType Directory -Path $tradesDir -Force | Out-Null
$byMonth = @{}
foreach ($t in $trades) {
  $month = Get-CloseMonth $t.closeTime
  if (-not $byMonth.ContainsKey($month)) { $byMonth[$month] = New-Object System.Collections.Generic.List[object] }
  $byMonth[$month].Add($t)
}
$monthKeys = @($byMonth.Keys | Sort-Object)
$monthSummaries = foreach ($month in $monthKeys) {
  $list = $byMonth[$month]
  $net = 0.0
  foreach ($t in $list) { $net += [double]$t.profit }
  [pscustomobject]@{ id = $month; net = [math]::Round($net, 2); trades = $list.Count }
}
Write-JsonFile -Path (Join-Path $standDir "months.json") -Object @{ months = @($monthSummaries) }
foreach ($month in $monthKeys) {
  Write-JsonFile -Path (Join-Path $tradesDir "$month.json") -Object @{ trades = $byMonth[$month].ToArray() }
}
$months = $monthKeys
$equityPoints = New-Object System.Collections.Generic.List[object]
foreach ($t in $trades) { $equityPoints.Add([pscustomobject]@{ t = $t.closeTime; b = $t.balance }) }
Write-JsonFile -Path (Join-Path $standDir "equity.json") -Object @{ points = $equityPoints.ToArray() }
Write-JsonFile -Path (Join-Path $standDir "trades_all.json") -Object @{ trades = $trades }

$bestWin = $null
$worstLoss = $null
foreach ($t in $trades) {
  if ($null -eq $bestWin -or [double]$t.profit -gt [double]$bestWin.profit) { $bestWin = $t }
  if ($null -eq $worstLoss -or [double]$t.profit -lt [double]$worstLoss.profit) { $worstLoss = $t }
}

$dailyDd = Get-DailyDrawdown -Trades $trades -Deposit $Deposit
$standEntry = @{
  id=$StandId; label= if ($Label) { $Label } else { $StandId }; symbol=$summary.symbol
  period= if ($Period) { $Period } else { "M5" }; deposit=$Deposit; risk=$Risk
  guard= if ($GuardLabel) { $GuardLabel } else { "" }; from=$summary.from; to=$summary.to
  model=$ModelLabel; broker=$Broker; net=[math]::Round($summary.net, 2)
  returnPct= if ($Deposit -gt 0) { [math]::Round(100.0 * $summary.net / $Deposit, 1) } else { 0 }
  profitFactor=[math]::Round($summary.profitFactor, 2)
  equityDdPct=[math]::Round($summary.equityDdPct, 2)
  equityDdMoney=[math]::Round($summary.equityDdMoney, 2)
  dailyDdPct=$dailyDd.pct
  dailyDdMoney=$dailyDd.money
  trades=$trades.Count; winRate=$summary.winRate
  equity="$StandId/equity.json"; months="$StandId/months.json"; tradesDir="$StandId/trades"
  bestWin=(Convert-TradeSummary $bestWin)
  worstLoss=(Convert-TradeSummary $worstLoss)
}
Update-StandsJson -StandsPath (Join-Path $DocsData "stands.json") -StandId $StandId -StandEntry $standEntry -ReplaceCatalog:$ReplaceCatalog
Write-Host "Exported $($trades.Count) trades across $($months.Count) months -> $standDir"
Write-Host "Summary: net=$($summary.net) PF=$($summary.profitFactor) trades=$($summary.totalTrades) equityDD=$($summary.equityDdPct)%"
