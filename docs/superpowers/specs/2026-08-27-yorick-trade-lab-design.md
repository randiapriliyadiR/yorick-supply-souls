# Yorick Trade Lab — Design Spec

**Date:** 2026-08-27  
**Status:** Approved (recommendations locked)  
**Repo:** `yorick-supply-souls` → GitHub Pages from `docs/`

## Goal

Replace the multi-preset guard grid lab with a **two-stand trade lab**: one best M5 stand and one best D1 stand. Each stand exposes a **balance/equity line chart**, a **month calendar filter**, and **per-trade history** (list + single-trade detail), with Yorick visual identity and FundedNext-like interaction patterns.

## Decisions (locked)

| Topic | Choice |
|--------|--------|
| M5 stand | **2% risk · Grave Guard 0.5R · deposit $200** (`YorickSoS_M5_200_R2p0_be05_tr05`) |
| D1 stand | **TP-only · risk 2% · deposit $100k** (`YorickSoS_XAUUSD_D1_tuned`) |
| UI skin | Yorick (hero, bronze/gold, Fraunces + Manrope) |
| UI features | Balance line chart, calendar month filter, trade list + one-by-one detail |
| M5 data strategy | Full equity/balance series + **trades loaded by month** (paginated chunks) |
| Architecture | Static HTML/CSS/JS on GitHub Pages; no backend |
| Out of scope | Guard preset grid, 1% M5 stand, BTC, live trading, API server |

## Stands

### M5 best

- Symbol: XAUUSD, Period: M5  
- Deposit: 200 USD, Risk: 2%, Model: 1 minute OHLC  
- Range: 2021.01.01 → 2026.08.26 (same as prior lab unless re-test updates `ToDate`)  
- Inputs: shipped soul defaults + `InpUseGuard=true`, BEP/trail start/dist = 0.5R  
- ~8k closed trades expected — must not ship as one monolithic trades JSON

### D1 best

- Symbol: XAUUSD, Period: D1  
- Deposit: 100000 USD, Risk: 2%  
- Guard: off / TP-only (match prior tuned lab)  
- ~49 trades — can ship as few monthly files or one small set

## Data pipeline

1. Re-run Strategy Tester via existing `Tester/run_backtest.ps1` for both stands (HTML report with deals).  
2. Parse MT5 HTML report (Orders/Deals + summary) with a new script `Tester/export_lab_data.ps1` (or `.py` if HTML parsing is cleaner).  
3. Emit into `docs/data/`:

```
docs/data/
  stands.json                 # catalog + summary metrics + paths
  m5_best/
    equity.json               # balance-after series for chart
    months.json               # ["2021-01", ...] months that have trades
    trades/
      2021-01.json            # trades closed (or opened) in that month
      ...
  d1_best/
    equity.json
    months.json
    trades/
      ...
```

### Trade object (minimum fields)

- `id` (ticket or synthetic stable id)  
- `side` (`buy` | `sell`)  
- `volume`  
- `openTime`, `closeTime` (ISO-8601 or MT5 `YYYY.MM.DD HH:MM`)  
- `openPrice`, `closePrice`  
- `profit` (net for closed position)  
- `balance` (account balance after this close)  
- Optional: `comment`, `commission`, `swap` if present in report

### Equity series

- Prefer **balance after each closed trade** rebuilt from deals (matches “perkembangan balance”).  
- If point count is huge, downsample for chart display only (e.g. keep last point per day) while keeping full trade files authoritative. Default: one point per closed trade is acceptable for ~8k points in Chart.js.

### Month chunking rule

- A trade belongs to the month of its **`closeTime`** (UTC or broker server time consistent with report).  
- `months.json` lists only months with ≥1 trade.  
- UI loads `trades/{yyyy-mm}.json` on demand when the calendar month is selected.

## UI / UX

### Global

- Keep Yorick hero + sticky section nav; remove guard-grid / full multi-preset ledger as primary UX.  
- Top stand switcher: **M5 best** | **D1 best** (same seg control pattern as today).  
- Accent gold/bronze; green/red for P/L only.

### Sections

1. **Overview** — cards: Net, PF, Equity DD%, Trades, Win rate; short stand meta (symbol, TF, deposit, risk, range, model).  
2. **Balance chart** — Chart.js line of balance over time; update when stand switches; optional vertical guide when a trade is selected.  
3. **Calendar** — month picker (prev/next + grid of available months from `months.json`). Selecting a month fetches that chunk and refreshes the trade list. Default: latest month with trades.  
4. **Trade history** — scrollable/paginated list for the selected month (e.g. 25 per page inside the month). Click row → detail panel.  
5. **Trade detail** — one trade at a time: side, volume, open/close time & price, profit, balance after; prev/next within the filtered month list.

### Removed / demoted

- Guard preset bar chart and 1%/2% risk grid.  
- “All reports” ledger of every lab preset (may keep a tiny footnote link to raw `stands.json` if useful; not required).

## Visual reference

- Interaction density inspired by FundedNext Figma (metrics + chart + calendar + history).  
- Visual language remains Yorick lab (not prop-firm sidebar clone).

## Performance / Pages constraints

- Initial load: `stands.json` + active stand `equity.json` + one month of trades.  
- No single JSON > ~2–3 MB preferred; monthly M5 files should stay small.  
- Lazy-fetch months; cache fetched months in memory for the session.

## Verification

- Local: open `docs/index.html` via static server or Pages preview; switch stands; scrub months; open trade detail.  
- Numbers on Overview cards match re-test summary (within rounding).  
- Sum of monthly trade counts = summary `trades`.  
- Deploy via existing `.github/workflows/pages.yml`.

## Non-goals

- Replacing portfolio site `randiapriliyadiR.github.io`.  
- Live account sync.  
- Optimization grid UI.

## Open implementation notes (not blockers)

- Exact MT5 HTML table selectors discovered during first parse of a fresh report.  
- Whether `ReplaceReport=1` writes `.htm` under Terminal data root (already handled by `run_backtest.ps1`).
