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

Daily bars are too sparse for a tiny balance to matter. For small-account lab notes we tested **XAUUSD M5** with the same tuned soul settings:

| Metric | Result |
|---|---:|
| Net profit | **+$833,622.61** |
| Ending balance | **~$833,823** |
| Profit factor | **1.10** |
| Total trades | 7,126 |
| Win rate | 42.1% |
| Equity drawdown max | **33.05%** |
| Balance drawdown max | 31.46% |

From **$200**, M5 produced many more fills than D1, but the march is **noisier** (~33% equity DD) and the headline net reflects heavy compounding across thousands of micro-lot souls. **Shipped defaults stay D1** for the cleaner edge; M5 is context for small-balance gold only.

### Why these defaults

A coarse-then-refine search on XAUUSD D1 (deposit $100k) beat the earlier strict factory preset by a wide margin:

| Preset | Net | Profit factor | Trades | Equity DD |
|---|---:|---:|---:|---:|
| Older factory-style | -$1,759 | 0.56 | 3 | 4.2% |
| **Shipped tuned (default)** | **+$23,816** | **1.39** | 49 | 17.2% |

### Gold stands at a glance

Same tuned soul inputs, 2021.01.01 -> 2026.08.26:

| Stand | Net | Profit factor | Trades | Notes |
|---|---:|---:|---:|---|
| **XAUUSD D1 ($100k)** | **+$23,816** | **1.39** | 49 | **Shipped default** |
| **XAUUSD M5 ($200)** | **+$833,623*** | 1.10 | 7,126 | Small-balance lab |

*M5 figures reflect thousands of fills and compounding - thinner edge per soul than D1.

**Takeaway:** **D1 + meaningful balance** for the tuned default; **M5** only if you must march gold on a tiny account.

## Install (MT5)

1. Copy this folder under `MQL5/Experts/Yorick Supply of Souls/`.
2. Copy `Indicators/*.mq5` into your terminal `MQL5/Indicators/`, then compile the EA and indicators in MetaEditor.
3. Attach **Yorick Supply of Souls** to a chart (XAUUSD D1 recommended).
4. Leave **Flock** / **Souls** inputs at defaults unless you know what you are changing.
5. Enable Algo Trading.

## Inputs (friendly names)

| Group | What you touch |
|---|---|
| Flock | Grave market filter, shepherd timeframe, soul budget %, identity stamp, slippage, spread fog |
| Souls | Breath period, surge length/body, structure bars, scan depth, gates, grave buffer |

Exact recipes stay in the mist - the published defaults are already the tuned shepherd.

## Disclaimer

Past backtests are not a promise of future profit. Gold can gap; drawdowns above 17% occurred in sample on large balance (33%+ on M5 small-balance lab). Use money you can afford to risk. This is research software, not financial advice.

## Author

**Randi Apriliyadi**  
Repository: [github.com/randiapriliyadiR/yorick-supply-souls](https://github.com/randiapriliyadiR/yorick-supply-souls)

Art reference: Arclight Yorick (League of Legends) - used here as naming inspiration for a patient gold shepherd.