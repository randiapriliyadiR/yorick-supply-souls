# Yorick Supply of Souls

<p align="center">
  <img src="media/yorick.jpg" alt="Yorick - gather the flock, mark the graves" width="520" />
</p>

> *"A man is very small when he is on his knees."*  
> An MT5 Expert Advisor named after Yorick - a shepherd of gold who waits for souls to return to marked graves.

**Lab reports (GitHub Pages):** [randiapriliyadiR.github.io/yorick-supply-souls](https://randiapriliyadiR.github.io/yorick-supply-souls/)

## What it is

**Yorick Supply of Souls** is a MetaTrader 5 expert that scans for high-quality return setups on gold, sizes each march from balance, and marks protection beyond the grave. Defaults ship **pre-tuned** for **XAUUSD M5** with **Grave Guard** (break-even + trailing) so a touched grave does not give the full risk back.

Companion to [Braum Following Trend](https://github.com/randiapriliyadiR/braum-following-trend) - same soul-budget discipline, different home market: **gold**, not crypto.

## Best verified stand (defaults) - v1.05

| Setting | Value |
|---|---|
| Symbol | XAUUSD |
| Timeframe | **M5** |
| Soul budget | 2% of balance per trade |
| Grave Guard | **ON** - BEP after **0.5R**, trail **0.5R** behind best |
| Range | 2021.01.01 -> 2026.08.26 |
| Model | 1 minute OHLC |
| Broker sample | Exness MT5 |

### Is Grave Guard (trailing) better?

**Yes on the shipped M5 stand.** Stress tests on **$200** M5 showed the tuned guard beat "TP only" on net, profit factor, and drawdown:

| Soul budget | Guard | Net | Profit factor | Equity DD |
|---|---|---:|---:|---:|
| **1%** | OFF (TP only) | +$13,519 | 1.12 | 17.4% |
| **1%** | **ON 0.5R / 0.5R** | **+$24,756** | **1.31** | **10.7%** |
| **2%** | OFF (TP only) | +$833,623* | 1.10 | 33.1% |
| **2%** | **ON 0.5R / 0.5R** | **+$6,063,100*** | **1.34** | **19.2%** |

\*2% M5 nets are inflated by heavy compounding across thousands of micro-lot fills - use them for ranking presets, not as a live promise.

Slower guards (BEP at 1R+) were **worse** than OFF on this sample. Fast lock at **0.5R** is the shipped recipe.

### Small balance - $200 (M5, shipped guard)

| Metric | Soul budget 2% + guard | Soul budget 1% + guard |
|---|---:|---:|
| Net profit | **+$6,063,100.22*** | **+$24,755.98** |
| Ending balance | **~$6,063,300** | **~$24,956** |
| Profit factor | **1.34** | **1.31** |
| Total trades | 8,324 | 8,187 |
| Equity drawdown max | **19.21%** | **10.69%** |

Prefer **1%** on a tiny live account if drawdown comfort matters; **2%** is the aggressive lab default.

### Large balance note - $100,000 (D1, lab only)

D1 is sparse (~50 trades). With TP-only it once printed about **+$19k–$24k** / PF ~1.3–1.4 / DD ~17–18%. Tight trailing on D1 often cut winners early in our grid - **do not treat D1+guard as the shipped recipe**. Defaults stay **M5 + Grave Guard**.

### Gold stands at a glance

Same soul inputs, 2021.01.01 -> 2026.08.26:

| Stand | Net | Profit factor | Equity DD | Notes |
|---|---:|---:|---:|---|
| **XAUUSD M5 ($200, 2%, guard ON)** | **+$6.06M*** | **1.34** | **19.2%** | **Shipped default path** |
| XAUUSD M5 ($200, 1%, guard ON) | +$24,756 | 1.31 | **10.7%** | Calmer small-balance |
| XAUUSD M5 ($200, 2%, guard OFF) | +$833,623* | 1.10 | 33.1% | No BEP/trail |
| XAUUSD M5 ($200, 1%, guard OFF) | +$13,519 | 1.12 | 17.4% | No BEP/trail |

**Takeaway:** On M5 gold, **Grave Guard ON (0.5R)** is clearly better than TP-only. Ship **M5**; use **1%** soul budget if you want the softer equity path.

## Install (MT5)

1. Clone/copy this folder under `MQL5/Experts/yorick-supply-souls/` (keep that folder name).
2. **Quick start (no compile):** attach the shipped `Yorick Supply of Souls.ex5` - overlays are already embedded. Refresh Navigator if it does not appear yet.
3. **From source (optional):** link headers once, then compile indicators before the EA:

```powershell
powershell -ExecutionPolicy Bypass -File ".\Tester\link_indicators.ps1"
```

   - `Indicators/Yorick Structure.mq5`
   - `Indicators/Yorick FVG.mq5`
   - `Indicators/Yorick Zones.mq5`
   - `Yorick Supply of Souls.mq5` (embeds the three `.ex5` via `#resource`)
4. Attach **Yorick Supply of Souls** to a chart (**XAUUSD M5** recommended).
5. Leave **Flock** / **Souls** / **Grave Guard** inputs at defaults unless you know what you are changing.
6. Enable Algo Trading.

Overlays ship inside the EA - no separate copy into `MQL5/Indicators` is required at runtime. Chart overlays are visual only and do not change entries.

## Inputs (friendly names)

| Group | What you touch |
|---|---|
| Flock | Grave market filter, shepherd timeframe, soul budget %, identity stamp, slippage, spread fog |
| Souls | Breath period, surge length/body, structure bars, scan depth, gates, grave buffer |
| Grave Guard | BEP + trail after a touch (lock the soul so a used grave cannot take full risk again) |

Exact recipes stay in the mist - the published defaults are already the tuned shepherd.

## Disclaimer

Past backtests are not a promise of future profit. Gold can gap; drawdowns near **11–19%** occurred in sample on M5 with guard (higher without it). Use money you can afford to risk. This is research software, not financial advice.

## Author

**Randi Apriliyadi**  
Repository: [github.com/randiapriliyadiR/yorick-supply-souls](https://github.com/randiapriliyadiR/yorick-supply-souls)

Naming inspiration: Yorick (League of Legends) - a patient gold shepherd gathering souls among the graves.