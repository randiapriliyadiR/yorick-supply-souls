//+------------------------------------------------------------------+
//| YorickSoS/Trend.mqh — validated swing trend bias (video 2)       |
//+------------------------------------------------------------------+
#ifndef YORICKSOS_TREND_MQH
#define YORICKSOS_TREND_MQH

#include "Types.mqh"
#include "Swings.mqh"

int YssTrendBias(const string symbol,
                 const ENUM_TIMEFRAMES tf,
                 const int strength,
                 const int lookback)
  {
   double highs[3];
   double lows[3];
   ArrayInitialize(highs, 0.0);
   ArrayInitialize(lows, 0.0);
   int hi = 0;
   int lo = 0;

   const int start = lookback - strength;
   const int stop = strength + 1;
   if(start <= stop)
      return 0;

   for(int s = start; s >= stop; s--)
     {
      if(hi < 3 && YssIsSwingHigh(symbol, tf, s, strength))
        {
         highs[hi++] = YssH(symbol, tf, s);
         if(hi >= 3 && lo >= 3)
            break;
        }
      if(lo < 3 && YssIsSwingLow(symbol, tf, s, strength))
        {
         lows[lo++] = YssL(symbol, tf, s);
         if(hi >= 3 && lo >= 3)
            break;
        }
     }

   if(hi < 2 || lo < 2)
      return 0;

   const bool hh = (highs[0] > highs[1]);
   const bool lh = (highs[0] < highs[1]);
   const bool hl = (lows[0] > lows[1]);
   const bool ll = (lows[0] < lows[1]);

   if(hh && hl)
      return 1;
   if(lh && ll)
      return -1;
   return 0;
  }

bool YssTrendGateAllows(const int zoneDir, const int trendBias, const bool requireTrend)
  {
   if(!requireTrend)
      return true;
   if(trendBias == 0)
      return false;
   return ((zoneDir > 0 && trendBias > 0) || (zoneDir < 0 && trendBias < 0));
  }

// Skip entries when trend-TF ATR is expanded vs its recent mean (chaos / news regime).
// Uses last closed bar ATR[1] vs mean of ATR[2 .. bars+1]. Fail-open if data missing.
bool YssAtrRegimeAllows(const SYssCfg &cfg)
  {
   if(!cfg.useAtrRegime)
      return true;
   if(g_hAtrTrend == INVALID_HANDLE || cfg.atrRegimeBars < 5 || cfg.atrRegimeMult <= 1.0)
      return true;

   const int need = cfg.atrRegimeBars + 3;
   double atr[];
   ArraySetAsSeries(atr, true);
   if(CopyBuffer(g_hAtrTrend, 0, 0, need, atr) < need)
      return true;

   const double now = atr[1];
   if(now <= 0.0)
      return true;

   double sum = 0.0;
   int n = 0;
   for(int i = 2; i < 2 + cfg.atrRegimeBars; i++)
     {
      if(atr[i] <= 0.0)
         continue;
      sum += atr[i];
      n++;
     }
   if(n < 5)
      return true;
   const double mean = sum / (double)n;
   if(mean <= 0.0)
      return true;
   // Extreme expansion only (first experiment)
   return (now <= mean * cfg.atrRegimeMult);
  }

#endif
//+------------------------------------------------------------------+
