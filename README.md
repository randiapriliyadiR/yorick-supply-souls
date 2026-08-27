# Yorick Supply of Souls

<p align="center">
  <img src="media/yorick.jpg" alt="Yorick - gather the flock, mark the graves" width="520" />
</p>

> *"A man is very small when he is on his knees."*  
> An MT5 Expert Advisor named after Yorick - a shepherd of gold who waits for souls to return to marked graves.

## What it is

**Yorick Supply of Souls** is a MetaTrader 5 expert that scans for high-quality return setups on gold, sizes each march from balance, and marks protection beyond the grave. Defaults ship **pre-tuned** for a patient **XAUUSD D1** stand.

Companion to [Braum Following Trend](https://github.com/randiapriliyadiR/braum-following-trend) - same soul-budget discipline, different home market: **gold**, not crypto.

## Best verified stand (defaults)

| Setting | Value |
|---|---|
| Symbol | XAUUSD |
| Timeframe | D1 |
| Soul budget | 2% of balance per trade |
| Range | 2021.01.01 -> 2026.08.26 |
| Model | 1 minute OHLC |
| Broker sample | Exness MT5 |

### Large balance - $100,000 (shipped default, D1)

| Metric | Result |
|---|---:|
| Net profit | **+$23,815.80** |
| Ending balance | **~$123,816** |
| Profit factor | **1.39** |
| Total trades | 49 |
| Win rate | 44.9% |
| Equity drawdown max | **17.21%** |
| Balance drawdown max | 9.94% |

On a **$100k** start, the tuned shepherd returned roughly **+24%** net over the sample with under **18%** equity drawdown - a calm, sparse cadence (~10 fills per year).

### Small balance - $200 (M5, same soul inputs)

Daily bars are too sparse for a tiny balance to matter. For small-account lab notes we tested **XAUUSD M5** with the same tuned soul settings at two soul budgets:

| Metric | Soul budget 2% | Soul budget 1% |
|---|---:|---:|
| Net profit | **+$833,622.61*** | **+$13,519.42** |
| Ending balance | **~$833,823** | **~$13,719** |
| Profit factor | **1.10** | **1.12** |
| Total trades | 7,126 | 7,077 |
| Win rate | 42.1% | 41.5% |
| Equity drawdown max | **33.05%** | **17.39%** |
| Balance drawdown max | 31.46% | 15.54% |

\*2% M5 net is inflated by heavy compounding across thousands of micro-lot fills.

From **$200**, M5 produces many more fills than D1. **2%** grows harder but deepens drawdown (~33%). **1%** keeps a similar trade count with roughly half the equity DD (~17%) - a calmer small-account march. **Shipped defaults stay D1 / 2%** for the cleaner large-balance edge; M5 is context for tiny gold accounts only.

### Why these defaults

A coarse-then-refine search on XAUUSD D1 (deposit $100k) beat the earlier strict factory preset by a wide margin:

| Preset | Net | Profit factor | Trades | Equity DD |
|---|---:|---:|---:|---:|
| Older factory-style | -$1,759 | 0.56 | 3 | 4.2% |
| **Shipped tuned (default)** | **+$23,816** | **1.39** | 49 | 17.2% |

### Gold stands at a glance

Same tuned soul inputs, 2021.01.01 -> 2026.08.26:

| Stand | Net | Profit factor | Trades | Equity DD | Notes |
|---|---:|---:|---:|---:|---|
| **XAUUSD D1 ($100k, 2%)** | **+$23,816** | **1.39** | 49 | 17.2% | **Shipped default** |
| **XAUUSD M5 ($200, 2%)** | **+$833,623*** | 1.10 | 7,126 | 33.1% | Aggressive small-balance lab |
| **XAUUSD M5 ($200, 1%)** | **+$13,519** | 1.12 | 7,077 | **17.4%** | Calmer small-balance lab |

*M5 2% figures reflect thousands of fills and compounding - thinner edge per soul than D1.

**Takeaway:** **D1 + meaningful balance** for the tuned default; on a tiny M5 gold account prefer **1% soul budget** over 2% if drawdown matters.

## Install (MT5)

1. Clone/copy this folder under `MQL5/Experts/yorick-supply-souls/` (keep that folder name).
2. **Quick start (no compile):** attach the shipped `Yorick Supply of Souls.ex5` — overlays are already embedded. Refresh Navigator if it does not appear yet.
3. **From source (optional):** link headers once, then compile indicators before the EA:

```powershell
powershell -ExecutionPolicy Bypass -File ".\Tester\link_indicators.ps1"
```

   - `Indicators/Yorick Structure.mq5`
   - `Indicators/Yorick FVG.mq5`
   - `Indicators/Yorick Zones.mq5`
   - `Yorick Supply of Souls.mq5` (embeds the three `.ex5` via `#resource`)
4. Attach **Yorick Supply of Souls** to a chart (XAUUSD D1 recommended).
5. Leave **Flock** / **Souls** inputs at defaults unless you know what you are changing.
6. Enable Algo Trading.

Overlays ship inside the EA — no separate copy into `MQL5/Indicators` is required at runtime.

## Inputs (friendly names)

| Group | What you touch |
|---|---|
| Flock | Grave market filter, shepherd timeframe, soul budget %, identity stamp, slippage, spread fog |
| Souls | Breath period, surge length/body, structure bars, scan depth, gates, grave buffer |

Exact recipes stay in the mist - the published defaults are already the tuned shepherd.

## Disclaimer

Past backtests are not a promise of future profit. Gold can gap; drawdowns above 17% occurred in sample on large balance (up to ~33% on M5 at 2% soul budget). Use money you can afford to risk. This is research software, not financial advice.

## Author

**Randi Apriliyadi**  
Repository: [github.com/randiapriliyadiR/yorick-supply-souls](https://github.com/randiapriliyadiR/yorick-supply-souls)

Art reference: Arclight Yorick (League of Legends) - used here as naming inspiration for a patient gold shepherd.