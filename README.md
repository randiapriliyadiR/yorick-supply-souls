# Yorick Supply of Souls

<p align="center">
  <img src="media/yorick.jpg" alt="Yorick - gather the flock, mark the graves" width="520" />
</p>

> *"A man is very small when he is on his knees."*  
> An MT5 Expert Advisor named after Yorick - a shepherd of gold who waits for souls to return to marked graves.

## Trade lab (GitHub Pages)

**URL:** [randiapriliyadir.github.io/yorick-supply-souls](https://randiapriliyadir.github.io/yorick-supply-souls/)

Interactive backtest explorer on **Exness real ticks** (`XAUUSD_Exness`, Model 4) with commission sim ($3.5/lot/side). Lab deposit: **$200**.

| Stand | Deposit | Risk | Net | Return | PF | Equity DD | WR | Trades |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| **Best $200** | $200 | 0.5% | +$71 | **+35%** | 1.12 | **24.7%** | **51%** | **166** |
| **Best $100k** | $100,000 | 0.5% | +$46,021 | **+46%** | 1.13 | **28.0%** | **51%** | **167** |

Same filters on both: **H4 trend**, zones **M5+M15**, Slow ON, MinRR OFF, SL ×2.0, Guard 0.5R.

## What it is

**Yorick Supply of Souls** scans return setups on gold across entry timeframes, sizes from balance, and locks risk with Grave Guard. Defaults ship for **usable frequency** on real ticks: Slow return is mandatory; MinRR is off because 2.5R + Slow left only ~5 trades in 4+ years.

## Best verified stand (defaults) - v1.11

| Setting | Value |
|---|---|
| Symbol | **XAUUSD_Exness** (imported Exness ticks) |
| Chart TF | **M5** |
| Trend TF | **H4** |
| Entry zones | **M5, M15** |
| Position mode | 1 position global |
| Soul budget | **0.5%** of balance |
| Lab deposit | **$200** (challenging small-account stand) |
| Gates | Trend + BOS + FVG + **Slow** (MinRR off) |
| SL buffer | **SlZoneMult = 2.0** (1× zone depth outside zone) |
| Grave Guard | **ON** — BEP / trail at **0.5R** |
| Commission (tester) | **$3.50 / lot / side** |
| Range | 2021.01.01 → 2025.12.31 |
| Model | **Every tick based on real ticks** |

### Retune takeaway (round 4)

| Focus | Net | PF | DD | WR | N |
|---|---:|---:|---:|---:|---:|
| **Shipped (Slow, no MinRR, 0.5%)** | **+$46k** | **1.13** | **28%** | **51%** | **167** |
| Growth (same, 1%) | +$209k | 1.31 | 29% | 53% | 153 |
| Slow + MinRR 1.5 | +$13k | 1.31 | 16% | 23% | 30 |
| No Slow | blown | &lt;1 | ~100% | low | 1200+ |

**Slow is non-negotiable.** MinRR 1.5–2.5 cuts sample and win rate without a clear health win for live use.

## Install (MT5)

1. Clone/copy this folder under `MQL5/Experts/yorick-supply-souls/` (keep that folder name).
2. **Quick start (no compile):** attach the shipped `Yorick Supply of Souls.ex5` - overlays are already embedded. Refresh Navigator if it does not appear yet.
3. **From source (optional):**

```powershell
powershell -ExecutionPolicy Bypass -File ".\Tester\link_indicators.ps1"
```

   Compile indicators then the EA.
4. Attach to **XAUUSD M5**. Enable Algo Trading.

## Inputs (friendly names)

| Group | What you touch |
|---|---|
| Flock | Market filter, chart/trend TF, entry zone TFs, 1-pos-per-TF, soul budget % |
| Souls | ATR / impulse / gates including Slow |
| Structure filters | Trend alignment, optional MinRR |
| Grave Guard | BEP + trail |
| Debug | Tester-only commission simulation |

## Disclaimer

Past backtests are not a promise of future profit. Equity DD near **25–29%** occurred on the published real-tick stands. Use money you can afford to risk. This is research software, not financial advice.

## Author

**Randi Apriliyadi**  
Repository: [github.com/randiapriliyadiR/yorick-supply-souls](https://github.com/randiapriliyadiR/yorick-supply-souls)
