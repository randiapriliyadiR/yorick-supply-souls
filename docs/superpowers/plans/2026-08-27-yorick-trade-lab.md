# Yorick Trade Lab Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a Yorick-skinned GitHub Pages lab with exactly two stands (M5 2% Guard 0.5R $200, D1 TP-only $100k), full balance charts, month-chunked trade history, and single-trade detail.

**Architecture:** Re-test both stands with `Tester/run_backtest.ps1`, parse MT5 HTML reports into `docs/data/{stands.json,m5_best/*,d1_best/*}`, rewrite `docs/` UI (stand switcher + chart + calendar + history). Static hosting only.

**Tech Stack:** MQL5 Strategy Tester, PowerShell parse/export, static HTML/CSS/JS, Chart.js 4.x, GitHub Pages workflow already in repo.

## Global Constraints

- Spec: `docs/superpowers/specs/2026-08-27-yorick-trade-lab-design.md`
- M5 stand only: deposit **200**, risk **2**, Guard **0.5/0.5/0.5**, period **M5**
- D1 stand only: deposit **100000**, risk **2**, Guard **false** / TP-only, period **D1**
- Range default: **2021.01.01** → **2026.08.26**, Model **1**
- Trades chunked by **closeTime** month; equity = balance after each close
- Do **not** modify `randiapriliyadiR.github.io` portfolio repo
- Keep Yorick visual language; no FundedNext sidebar clone
- Do not invent trade rows — only parse tester output

## File map

| Path | Role |
|------|------|
| `Tester/run_backtest.ps1` | Existing headless tester (reuse) |
| `Tester/export_lab_data.ps1` | Create: parse HTML → `docs/data/...` |
| `docs/data/stands.json` | Catalog + summaries |
| `docs/data/m5_best/**` | Equity + months + trade chunks |
| `docs/data/d1_best/**` | Same for D1 |
| `docs/index.html` | Lab shell (overview/chart/calendar/history) |
| `docs/styles.css` | Yorick styles + new lab widgets |
| `docs/app.js` | Stand switch, chart, calendar fetch, detail |
| `docs/data/reports.json` | Demote/remove from UI (may delete after migration) |

---

### Task 1: Re-test M5 best and D1 best (HTML reports)

**Files:**
- Use: `Tester/run_backtest.ps1`
- Produce: Terminal HTML reports + `Tester/last_summary_*.txt`

**Interfaces:**
- Produces: HTML paths printed by script (typically under Terminal data root `YorickSoS_*.htm`) and summaries for later parse

- [ ] **Step 1: Run M5 best backtest**

```powershell
cd "C:\Users\randi\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Experts\Yorick Supply of Souls\Tester"
.\run_backtest.ps1 `
  -Symbol XAUUSD -Period M5 `
  -Deposit 200 -RiskPct 2.0 `
  -UseGuard true -BeTriggerR 0.5 -TrailStartR 0.5 -TrailDistR 0.5 `
  -ReportName "YorickSoS_lab_m5_best" `
  -FromDate 2021.01.01 -ToDate 2026.08.26 -Model 1 `
  -TimeoutSec 7200
```

Expected: exit 0; `last_summary_YorickSoS_lab_m5_best.txt` exists; HTML report exists; Total Trades roughly ~8000+.

- [ ] **Step 2: Run D1 best backtest**

```powershell
.\run_backtest.ps1 `
  -Symbol XAUUSD -Period D1 `
  -Deposit 100000 -RiskPct 2.0 `
  -UseGuard false `
  -ReportName "YorickSoS_lab_d1_best" `
  -FromDate 2021.01.01 -ToDate 2026.08.26 -Model 1 `
  -TimeoutSec 3600 -SkipCompile
```

Expected: exit 0; ~40–60 trades; Net Profit near prior tuned (~+23k order of magnitude).

- [ ] **Step 3: Locate HTML report files**

```powershell
$td = "C:\Users\randi\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075"
Get-ChildItem $td -Filter "YorickSoS_lab_*.htm*" | Select-Object FullName, Length, LastWriteTime
```

Expected: both `YorickSoS_lab_m5_best.htm` and `YorickSoS_lab_d1_best.htm` (or `.html`).

- [ ] **Step 4: Commit only if summaries are stored in-repo**

Copy summaries into `Tester/` if not already there (script already writes `last_summary_*.txt`). Do **not** commit huge HTML into git unless under ~2MB; prefer parse → JSON only.

```powershell
git add Tester/last_summary_YorickSoS_lab_m5_best.txt Tester/last_summary_YorickSoS_lab_d1_best.txt
git commit --trailer "Co-authored-by: Cursor <cursoragent@cursor.com>" -m "chore: capture lab M5/D1 best backtest summaries"
```

---

### Task 2: Build `export_lab_data.ps1` parser

**Files:**
- Create: `Tester/export_lab_data.ps1`
- Create: `Tester/tests/export_lab_data.tests.ps1` (optional smoke) OR a small fixture excerpt

**Interfaces:**
- Consumes: path to MT5 HTML report, stand id (`m5_best` | `d1_best`), deposit
- Produces: writes under `docs/data/<standId>/` and updates `docs/data/stands.json` entry

- [ ] **Step 1: Create failing smoke that requires script**

```powershell
# Tester/tests/smoke_export.ps1
$script = Join-Path $PSScriptRoot "..\export_lab_data.ps1"
if (-not (Test-Path $script)) { throw "export_lab_data.ps1 missing" }
```

Run:

```powershell
powershell -File ".\Tester\tests\smoke_export.ps1"
```

Expected: FAIL (`export_lab_data.ps1 missing`) until Step 2.

- [ ] **Step 2: Implement parser**

Create `Tester/export_lab_data.ps1` with parameters:

```powershell
param(
  [Parameter(Mandatory)][string]$HtmlPath,
  [Parameter(Mandatory)][ValidateSet("m5_best","d1_best")][string]$StandId,
  [Parameter(Mandatory)][double]$Deposit,
  [string]$DocsData = "",
  [string]$Label = "",
  [string]$Period = "",
  [double]$Risk = 2,
  [string]$GuardLabel = ""
)
```

Behavior:

1. Read HTML as Unicode/UTF-8 (detect BOM).  
2. Parse summary: Total Net Profit, Profit Factor, Equity DD Maximal (amount + %), Total Trades, Profit Trades.  
3. Parse **Deals** or closed **Orders** table into closed round-trips (prefer Deals with entry/out pairs, or Positions history if present).  
4. Build array of trade objects with fields from spec.  
5. Running balance: start at `$Deposit`, add each trade `profit` (and commission/swap if in row).  
6. Write:
   - `equity.json` → `{ "points": [ {"t":"<closeTime>","b":<balance>} ] }`
   - `months.json` → `{ "months": ["YYYY-MM", ...] }` sorted
   - `trades/YYYY-MM.json` → `{ "trades": [ ... ] }` for each month
7. Upsert `stands.json`:

```json
{
  "version": "1.05.0",
  "updated": "YYYY-MM-DD",
  "defaultStand": "m5_best",
  "stands": [
    {
      "id": "m5_best",
      "label": "M5 $200 · 2% · Guard 0.5R",
      "symbol": "XAUUSD",
      "period": "M5",
      "deposit": 200,
      "risk": 2,
      "guard": "0.5R",
      "from": "2021.01.01",
      "to": "2026.08.26",
      "model": "1 minute OHLC",
      "broker": "Exness MT5",
      "net": 0,
      "profitFactor": 0,
      "equityDdPct": 0,
      "trades": 0,
      "winRate": "",
      "equity": "m5_best/equity.json",
      "months": "m5_best/months.json",
      "tradesDir": "m5_best/trades"
    }
  ]
}
```

Numeric fields filled from parsed summary.

- [ ] **Step 3: Re-run smoke / dry-run on D1 HTML first**

```powershell
.\export_lab_data.ps1 -HtmlPath "<path\to\YorickSoS_lab_d1_best.htm>" -StandId d1_best -Deposit 100000 `
  -Label "D1 `$100k · 2% · TP only" -Period D1 -Risk 2 -GuardLabel "TP only"
```

Expected: `docs/data/d1_best/equity.json`, `months.json`, at least one `trades/*.json`; trade count matches summary.

- [ ] **Step 4: Export M5**

```powershell
.\export_lab_data.ps1 -HtmlPath "<path\to\YorickSoS_lab_m5_best.htm>" -StandId m5_best -Deposit 200 `
  -Label "M5 `$200 · 2% · Guard 0.5R" -Period M5 -Risk 2 -GuardLabel "0.5R"
```

Expected: many monthly files; sum of trades across months = summary trades; `stands.json` has both stands.

- [ ] **Step 5: Commit exporter + generated data**

```powershell
git add Tester/export_lab_data.ps1 Tester/tests/smoke_export.ps1 docs/data/stands.json docs/data/m5_best docs/data/d1_best
git commit --trailer "Co-authored-by: Cursor <cursoragent@cursor.com>" -m "feat: export month-chunked trade lab data from MT5 reports"
```

---

### Task 3: Rebuild Pages UI shell (HTML + CSS)

**Files:**
- Modify: `docs/index.html`
- Modify: `docs/styles.css`

**Interfaces:**
- Produces: DOM ids consumed by `app.js`: `tf-seg`, `overview-stats`, `chart-balance`, `cal-label`, `cal-prev`, `cal-next`, `cal-grid`, `trade-list`, `trade-detail`, `stand-meta`

- [ ] **Step 1: Replace main structure in `docs/index.html`**

Keep hero + Yorick assets. Main content:

```html
<main class="wrap">
  <div class="lab-bar">
    <p class="lab-bar-label">Best stand</p>
    <div class="seg" id="tf-seg" role="tablist">
      <button type="button" class="seg-btn active" data-stand="m5_best">M5 best</button>
      <button type="button" class="seg-btn" data-stand="d1_best">D1 best</button>
    </div>
  </div>

  <section id="overview" class="block">
    <h2>Overview</h2>
    <p class="deck" id="stand-meta"></p>
    <dl class="stat-list" id="overview-stats"></dl>
  </section>

  <section id="chart" class="block">
    <h2>Balance</h2>
    <div class="chart-box"><canvas id="chart-balance" height="140"></canvas></div>
  </section>

  <section id="calendar" class="block">
    <h2>Calendar</h2>
    <div class="cal-nav">
      <button type="button" id="cal-prev" aria-label="Previous month">‹</button>
      <p id="cal-label"></p>
      <button type="button" id="cal-next" aria-label="Next month">›</button>
    </div>
    <div class="cal-grid" id="cal-grid"></div>
  </section>

  <section id="history" class="block">
    <h2>Trade history</h2>
    <div class="history-layout">
      <div class="table-scroll">
        <table>
          <thead>
            <tr>
              <th>Close</th><th>Side</th><th>Lots</th><th>P/L</th><th>Balance</th>
            </tr>
          </thead>
          <tbody id="trade-list"></tbody>
        </table>
      </div>
      <aside class="trade-detail" id="trade-detail">
        <p class="mute">Select a trade</p>
      </aside>
    </div>
    <div class="pager">
      <button type="button" id="page-prev">Prev</button>
      <span id="page-label"></span>
      <button type="button" id="page-next">Next</button>
    </div>
  </section>
</main>
```

Update sticky nav links to `#overview #chart #calendar #history`.

- [ ] **Step 2: Add CSS for calendar + history split**

In `docs/styles.css` append (keep existing Yorick tokens):

```css
.cal-nav { display:flex; align-items:center; justify-content:center; gap:1rem; margin-bottom:1rem; }
.cal-nav button { appearance:none; border:1px solid var(--line); background:transparent; color:var(--text); width:2.5rem; height:2.5rem; cursor:pointer; font-size:1.25rem; }
.cal-grid { display:grid; grid-template-columns:repeat(auto-fill,minmax(4.5rem,1fr)); gap:0.5rem; margin-bottom:0.5rem; }
.cal-cell { border:1px solid var(--line); padding:0.55rem 0.25rem; text-align:center; cursor:pointer; color:var(--mute); background:transparent; font:inherit; }
.cal-cell.has { color:var(--text); }
.cal-cell.active { border-color:var(--gold); background:rgba(201,162,39,0.15); color:var(--gold-soft); }
.cal-cell:disabled { opacity:0.35; cursor:default; }
.history-layout { display:grid; gap:1.25rem; }
@media (min-width:900px) {
  .history-layout { grid-template-columns: 1.4fr 1fr; align-items:start; }
}
.trade-detail { border:1px solid var(--line); padding:1rem 1.1rem; min-height:12rem; }
.trade-detail h3 { font-family:var(--display); margin:0 0 0.75rem; }
.trade-detail dl { display:grid; grid-template-columns:auto 1fr; gap:0.35rem 0.75rem; margin:0; }
.trade-detail dt { color:var(--mute); }
.trade-detail dd { margin:0; text-align:right; }
#trade-list tr { cursor:pointer; }
#trade-list tr.active { background:rgba(201,162,39,0.12); }
.pager { display:flex; gap:0.75rem; align-items:center; justify-content:center; margin-top:1rem; }
```

- [ ] **Step 3: Visual check**

Open `docs/index.html` in browser (structure only; JS next). Expected: hero + empty sections + M5/D1 seg.

- [ ] **Step 4: Commit**

```powershell
git add docs/index.html docs/styles.css
git commit --trailer "Co-authored-by: Cursor <cursoragent@cursor.com>" -m "feat: scaffold trade lab UI shell with calendar and history"
```

---

### Task 4: Implement `app.js` lab runtime

**Files:**
- Modify: `docs/app.js` (replace grid logic)

**Interfaces:**
- Consumes: `./data/stands.json`, `./data/<equity|months>`, `./data/<tradesDir>/<yyyy-mm>.json`
- Produces: rendered overview, Chart.js balance line, calendar, paged trade list, detail panel

- [ ] **Step 1: Replace `app.js` with stand-driven loader**

Core state:

```javascript
let DATA = null;          // stands.json
let standId = "m5_best";
let equityChart = null;
let months = [];
let monthIdx = 0;
let monthTrades = [];
let page = 0;
const PAGE_SIZE = 25;
let selectedTradeId = null;
const monthCache = new Map();
```

Functions (exact names):

- `money(n)`, `pct(n)` — keep formatting helpers  
- `stand()` → current stand object  
- `async loadStands()`  
- `async loadEquity(stand)`  
- `async loadMonths(stand)`  
- `async loadMonthTrades(stand, yyyyMm)` — use cache  
- `renderOverview()`  
- `renderChart(points)`  
- `renderCalendar()`  
- `renderTradeList()`  
- `renderTradeDetail(trade)`  
- `async setStand(id)`  
- `async setMonthByIndex(i)`  
- `boot()`

Fetch base: `./data/` + relative paths from stand record.

Paging: `page` indexes into `monthTrades` with `PAGE_SIZE`.

Calendar grid: list all `months` as buttons; highlight active; enable only months in list.

- [ ] **Step 2: Wire events**

- `#tf-seg .seg-btn` → `setStand(dataset.stand)`  
- `#cal-prev` / `#cal-next` → move `monthIdx`  
- `#cal-grid` click → set month  
- `#trade-list` row click → select trade + optional chart annotation  
- `#page-prev` / `#page-next` → page ±1  

- [ ] **Step 3: Manual test checklist**

1. Default loads M5 overview numbers matching `stands.json`.  
2. Chart draws rising/falling balance.  
3. Calendar shows many months for M5; few for D1.  
4. Changing month fetches new JSON (Network tab) and refreshes list.  
5. Click trade fills detail; Prev/Next page works.  
6. Switch to D1 resets month to last D1 month.

- [ ] **Step 4: Commit**

```powershell
git add docs/app.js
git commit --trailer "Co-authored-by: Cursor <cursoragent@cursor.com>" -m "feat: wire balance chart, calendar months, and trade detail"
```

---

### Task 5: Cleanup old lab data + README + deploy

**Files:**
- Delete or stop referencing: `docs/data/reports.json` (if unused)  
- Modify: `README.md` (lab URL + describe two stands + trade explorer)  
- Touch: `.github/workflows/pages.yml` only if path triggers need change (usually unchanged)

- [ ] **Step 1: Remove dead UI data**

```powershell
git rm docs/data/reports.json
```

If anything still imports it, update first.

- [ ] **Step 2: README blurb**

Add short section:

- Lab URL: `https://randiapriliyadir.github.io/yorick-supply-souls/`  
- Stands: M5 2% Guard 0.5R ($200), D1 TP-only ($100k)  
- Features: balance chart, month calendar, per-trade history  

- [ ] **Step 3: Commit and push**

```powershell
git add README.md
git commit --trailer "Co-authored-by: Cursor <cursoragent@cursor.com>" -m "docs: point README at two-stand trade lab"
git push origin HEAD
```

- [ ] **Step 4: Verify Actions + live site**

```powershell
# after push, confirm workflow success then:
Invoke-WebRequest https://randiapriliyadir.github.io/yorick-supply-souls/ -UseBasicParsing | Select-Object StatusCode
```

Expected: 200; page contains Overview/Balance/Calendar; stand switch works.

---

## Spec coverage check

| Spec requirement | Task |
|------------------|------|
| Two stands only (M5 2% Guard, D1 TP-only) | 1, 2, 4 |
| Re-test for detail trades | 1 |
| Month-chunked trades + full equity | 2 |
| Balance line chart | 3, 4 |
| Calendar filter | 3, 4 |
| History one-by-one detail | 3, 4 |
| Yorick skin + FundedNext-like features | 3, 4 |
| GitHub Pages deploy | 5 |
| Do not touch portfolio repo | Global |

## Placeholder scan

None intentional — HTML selectors for MT5 tables are discovered in Task 2 against real files from Task 1 (allowed implementation discovery, not a TBD feature).
