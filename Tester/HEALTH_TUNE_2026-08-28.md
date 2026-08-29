# Health retune round 4 - usable frequency (2026-08-29)

Model 4 real ticks, XAUUSD_Exness, commission $3.5/lot/side, 2021.01.01-2025.07.15.

## Lesson
MinRR 2.5 + Slow = only ~5 trades (too rare).
Slow OFF = account blowup (~100% DD).
Keep Slow ON; turn MinRR OFF for usable sample.

## Round 4 grid (highlights)

| Preset | Net | PF | Eq DD | WR | Trades |
|---|---:|---:|---:|---:|---:|
| Slow+MinRR1.5 | +8k | 1.19 | 17% | 25% | 28 |
| Slow+MinRR2.0 | +2k | 1.13 | 19% | 20% | 10 |
| Slow no MinRR M5/M15 0.5% | +83k | 1.29 | 25% | 53% | 153 |
| Slow no MinRR M5/M15 1% | +209k | 1.31 | 29% | 53% | 153 |
| No Slow | blown | <1 | 100% | low | 1200+ |

## Shipped defaults
- Zones M5,M15 | OnePosPerTf false | Risk 0.5%
- Slow ON | MinRR OFF | Trend ON | Guard 0.5R
- Lab: mtf_healthy = 0.5% | mtf_active = 1% (same filters)
