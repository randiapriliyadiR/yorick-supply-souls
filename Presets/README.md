# Yorick Supply of Souls — MT5 presets (.set)

Load in MT5: attach EA → Inputs → Load → pick a file from this folder.

| File | Account / ticks | Notes |
|------|-----------------|-------|
| `YorickSoS_XAU_RawBest.set` | `XAUUSD_Exness` Raw | SlowMax **0.8** |
| `YorickSoS_XAU_ProBest.set` | `XAUUSD_ExnessPro` | SlowMax **0.7** |
| `YorickSoS_EUR_ProBest.set` | `EURUSD_ExnessPro` | M15 · Risk **1.5%** · MinRR **1.5** (~+42% / DD ~18%) |
| `YorickSoS_EUR_ProSafe.set` | `EURUSD_ExnessPro` | Risk **0.5%** · MinRR **1.8** (~+9% / DD ~3%) |
| `YorickSoS_USTEC_ProVideoH4.set` | `USTEC_ExnessPro` | **Video baseline** H4 · Risk **2%** · SlowMax **1.0** · Guard **1.0R** (thin: 11 trades) |

Lab portfolio (`mtf_200` / `mtf_100k`) now defaults **XAU + EUR** both ON.
