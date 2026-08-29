//+------------------------------------------------------------------+
//| YorickSoS/Zones.mqh — supply/demand from opposite candle + impulse|
//+------------------------------------------------------------------+
#ifndef YORICKSOS_ZONES_MQH
#define YORICKSOS_ZONES_MQH

#include "Types.mqh"
#include "Swings.mqh"
#include "Fvg.mqh"
#include "Risk.mqh"

bool YssCandleBear(const string symbol, const ENUM_TIMEFRAMES tf, const int shift)
  {
   return (YssC(symbol, tf, shift) < YssO(symbol, tf, shift));
  }

bool YssCandleBull(const string symbol, const ENUM_TIMEFRAMES tf, const int shift)
  {
   return (YssC(symbol, tf, shift) > YssO(symbol, tf, shift));
  }

double YssBody(const string symbol, const ENUM_TIMEFRAMES tf, const int shift)
  {
   return MathAbs(YssC(symbol, tf, shift) - YssO(symbol, tf, shift));
  }

bool YssWalkImpulse(const string symbol,
                    const ENUM_TIMEFRAMES tf,
                    const int baseShift,
                    const int dir,
                    const int maxBars,
                    int &endShift,
                    double &runExtreme,
                    double &maxBody)
  {
   const int first = baseShift - 1;
   if(first < 1)
      return false;

   const double zH = YssH(symbol, tf, baseShift);
   const double zL = YssL(symbol, tf, baseShift);
   endShift = first;
   maxBody = 0.0;
   runExtreme = (dir > 0 ? YssH(symbol, tf, first) : YssL(symbol, tf, first));

   for(int j = first; j >= 1; j--)
     {
      if(first - j + 1 > maxBars)
         break;

      const double body = YssBody(symbol, tf, j);
      if(body > maxBody)
         maxBody = body;

      if(dir > 0)
        {
         if(YssH(symbol, tf, j) > runExtreme)
            runExtreme = YssH(symbol, tf, j);
         if(j < first && YssL(symbol, tf, j) <= zH)
            break;
        }
      else
        {
         if(YssL(symbol, tf, j) < runExtreme)
            runExtreme = YssL(symbol, tf, j);
         if(j < first && YssH(symbol, tf, j) >= zL)
            break;
        }
      endShift = j;
     }

   return (first - endShift + 1 >= 2);
  }

int YssPeakShift(const string symbol,
                 const ENUM_TIMEFRAMES tf,
                 const int firstShift,
                 const int endShift,
                 const int dir)
  {
   int peak = firstShift;
   for(int j = firstShift; j >= endShift; j--)
     {
      if(dir > 0)
        {
         if(YssH(symbol, tf, j) >= YssH(symbol, tf, peak))
            peak = j;
        }
      else
        {
         if(YssL(symbol, tf, j) <= YssL(symbol, tf, peak))
            peak = j;
        }
     }
   return peak;
  }

bool YssClosedTouch(const string symbol,
                    const ENUM_TIMEFRAMES tf,
                    const SYssZone &z,
                    const int endShift)
  {
   for(int j = endShift - 1; j >= 1; j--)
     {
      if(z.dir > 0)
        {
         if(YssL(symbol, tf, j) <= z.zoneHigh)
            return true;
        }
      else
        {
         if(YssH(symbol, tf, j) >= z.zoneLow)
            return true;
        }
     }
   return false;
  }

bool YssClosedThrough(const string symbol,
                      const ENUM_TIMEFRAMES tf,
                      const SYssZone &z)
  {
   const double c1 = YssC(symbol, tf, 1);
   if(z.dir > 0)
      return (c1 < z.zoneLow);
   return (c1 > z.zoneHigh);
  }

bool YssBuildZoneAt(const SYssCfg &cfg,
                    const ENUM_TIMEFRAMES tf,
                    const int baseShift,
                    const int dir,
                    const double atr,
                    SYssZone &z,
                    const bool requireFresh)
  {
   YssZoneClear(z);
   if(baseShift < 3 || atr <= 0.0)
      return false;

   const string symbol = cfg.symbol;

   if(dir > 0)
     {
      if(!YssCandleBear(symbol, tf, baseShift))
         return false;
     }
   else if(!YssCandleBull(symbol, tf, baseShift))
      return false;

   int endShift = 0;
   double runExtreme = 0.0;
   double maxBody = 0.0;
   if(!YssWalkImpulse(symbol, tf, baseShift, dir, cfg.maxImpulseBars,
                      endShift, runExtreme, maxBody))
      return false;

   const double zH = YssH(symbol, tf, baseShift);
   const double zL = YssL(symbol, tf, baseShift);
   const double disp = (dir > 0 ? runExtreme - zL : zH - runExtreme);
   if(disp < cfg.impulseAtrMult * atr)
      return false;
   if(maxBody < cfg.bodyAtrMult * atr)
      return false;

   double fvgTop = 0.0, fvgBot = 0.0;
   const bool hasFvg = (dir > 0
                        ? YssBullishFvgAtBase(symbol, tf, baseShift, fvgTop, fvgBot)
                        : YssBearishFvgAtBase(symbol, tf, baseShift, fvgTop, fvgBot));
   if(cfg.requireFvg && !hasFvg)
      return false;

   double swingLvl = 0.0;
   datetime swingWhen = 0;
   datetime bosTime = 0;
   bool hasBos = false;
   const int first = baseShift - 1;
   if(dir > 0)
     {
      if(YssSwingHighBefore(symbol, tf, baseShift, cfg.swingStrength, cfg.lookback,
                            swingLvl, swingWhen))
         hasBos = YssBosDemand(symbol, tf, first, endShift, swingLvl, bosTime);
     }
   else
     {
      if(YssSwingLowBefore(symbol, tf, baseShift, cfg.swingStrength, cfg.lookback,
                           swingLvl, swingWhen))
         hasBos = YssBosSupply(symbol, tf, first, endShift, swingLvl, bosTime);
     }
   if(cfg.requireBos && !hasBos)
      return false;

   const int peak = YssPeakShift(symbol, tf, first, endShift, dir);

   z.valid = true;
   z.dir = dir;
   z.zoneTf = tf;
   z.baseTime = YssT(symbol, tf, baseShift);
   z.peakTime = YssT(symbol, tf, peak);
   z.bosTime = bosTime;
   z.zoneHigh = zH;
   z.zoneLow = zL;
   z.impulseExtreme = runExtreme;
   z.fvgTop = fvgTop;
   z.fvgBot = fvgBot;
   z.hasBos = hasBos;
   z.hasFvg = hasFvg;
   YssFillZoneStops(z, cfg.slZoneMult);

   if(z.baseTime == 0 || z.zoneHigh <= z.zoneLow)
     {
      YssZoneClear(z);
      return false;
     }
   if(requireFresh && YssClosedTouch(symbol, tf, z, endShift))
     {
      YssZoneClear(z);
      return false;
     }
   return true;
  }

int YssFindZoneIndex(const int tfIdx, const datetime baseTime)
  {
   if(tfIdx < 0 || tfIdx >= g_yss_cfg.zoneTfCount || baseTime == 0)
      return -1;
   for(int i = 0; i < g_yss_zoneCount[tfIdx]; i++)
     {
      if(g_yss_zones[tfIdx][i].baseTime == baseTime)
         return i;
     }
   return -1;
  }

void YssZonePushTf(const int tfIdx, const SYssZone &z)
  {
   if(tfIdx < 0 || tfIdx >= g_yss_cfg.zoneTfCount)
      return;
   const int existing = YssFindZoneIndex(tfIdx, z.baseTime);
   if(existing >= 0)
     {
      g_yss_zones[tfIdx][existing] = z;
      return;
     }
   if(g_yss_zoneCount[tfIdx] >= YSS_MAX_ZONES)
     {
      for(int i = 1; i < YSS_MAX_ZONES; i++)
         g_yss_zones[tfIdx][i - 1] = g_yss_zones[tfIdx][i];
      g_yss_zoneCount[tfIdx] = YSS_MAX_ZONES - 1;
     }
   g_yss_zones[tfIdx][g_yss_zoneCount[tfIdx]++] = z;
  }

void YssZoneRemoveAt(const int tfIdx, const int slot)
  {
   if(tfIdx < 0 || tfIdx >= g_yss_cfg.zoneTfCount)
      return;
   if(slot < 0 || slot >= g_yss_zoneCount[tfIdx])
      return;
   for(int i = slot + 1; i < g_yss_zoneCount[tfIdx]; i++)
      g_yss_zones[tfIdx][i - 1] = g_yss_zones[tfIdx][i];
   g_yss_zoneCount[tfIdx]--;
  }

void YssScanZonesTf(const int tfIdx,
                    SYssZone &kept[],
                    int &keptCount)
  {
   keptCount = 0;
   if(tfIdx < 0 || tfIdx >= g_yss_cfg.zoneTfCount)
      return;

   const SYssCfg cfg = g_yss_cfg;
   const ENUM_TIMEFRAMES tf = cfg.zoneTfs[tfIdx];
   const int atrHandle = g_hAtrZone[tfIdx];
   const int need = cfg.lookback;
   if(atrHandle == INVALID_HANDLE)
      return;
   if(!YssSeriesLoad(cfg.symbol, tf, need + 5))
      return;

   double atr[];
   ArraySetAsSeries(atr, true);
   if(CopyBuffer(atrHandle, 0, 0, need + 2, atr) < need)
      return;

   const int cap = YSS_MAX_ZONES * 2;
   for(int b = 3; b <= need - cfg.swingStrength - 1; b++)
     {
      const datetime bt = YssT(cfg.symbol, tf, b);
      if(bt == 0 || YssUsedContains(bt, tf))
         continue;
      const double a = atr[b];
      if(a <= 0.0)
         continue;

      SYssZone z;
      if(YssBuildZoneAt(cfg, tf, b, 1, a, z, true))
        {
         kept[keptCount++] = z;
         if(keptCount >= cap)
            break;
        }
      else if(YssBuildZoneAt(cfg, tf, b, -1, a, z, true))
        {
         kept[keptCount++] = z;
         if(keptCount >= cap)
            break;
        }
     }
  }

void YssRescanAllZones(void)
  {
   // Each entry TF keeps its own book — no shared pool / no crowding.
   for(int tfIdx = 0; tfIdx < g_yss_cfg.zoneTfCount; tfIdx++)
     {
      SYssZone kept[YSS_MAX_ZONES * 2];
      int keptCount = 0;
      YssScanZonesTf(tfIdx, kept, keptCount);

      g_yss_zoneCount[tfIdx] = 0;
      const int start = MathMax(0, keptCount - YSS_MAX_ZONES);
      for(int i = start; i < keptCount; i++)
         YssZonePushTf(tfIdx, kept[i]);
     }
  }

void YssScanZones(const double &atr[])
  {
   YssRescanAllZones();
  }

void YssInvalidatePending(void)
  {
   for(int tfIdx = 0; tfIdx < g_yss_cfg.zoneTfCount; tfIdx++)
     {
      const ENUM_TIMEFRAMES tf = g_yss_cfg.zoneTfs[tfIdx];
      for(int i = g_yss_zoneCount[tfIdx] - 1; i >= 0; i--)
        {
         if(!g_yss_zones[tfIdx][i].valid)
           {
            YssZoneRemoveAt(tfIdx, i);
            continue;
           }
         if(YssClosedThrough(g_yss_cfg.symbol, tf, g_yss_zones[tfIdx][i]))
           {
            YssUsedAdd(g_yss_zones[tfIdx][i].baseTime, tf);
            YssZoneRemoveAt(tfIdx, i);
           }
        }
     }
  }

// Prefer finer TF when several zones are touched at once (one position only).
bool YssTouchedZoneAtTf(const int tfIdx,
                        const double ask, const double bid,
                        SYssZone &out, int &slotOut)
  {
   YssZoneClear(out);
   slotOut = -1;
   if(tfIdx < 0 || tfIdx >= g_yss_cfg.zoneTfCount)
      return false;

   for(int i = g_yss_zoneCount[tfIdx] - 1; i >= 0; i--)
     {
      SYssZone z = g_yss_zones[tfIdx][i];
      if(!z.valid)
         continue;
      if(z.dir > 0)
        {
         if(ask <= z.zoneHigh && bid >= z.zoneLow)
           {
            out = z;
            slotOut = i;
            return true;
           }
         if(ask < z.zoneLow)
           {
            YssUsedAdd(z.baseTime, z.zoneTf);
            YssZoneRemoveAt(tfIdx, i);
           }
        }
      else
        {
         if(bid >= z.zoneLow && ask <= z.zoneHigh)
           {
            out = z;
            slotOut = i;
            return true;
           }
         if(bid > z.zoneHigh)
           {
            YssUsedAdd(z.baseTime, z.zoneTf);
            YssZoneRemoveAt(tfIdx, i);
           }
        }
     }
   return false;
  }

bool YssTouchedZone(const double ask, const double bid,
                    SYssZone &out, int &tfIdxOut, int &slotOut)
  {
   YssZoneClear(out);
   tfIdxOut = -1;
   slotOut = -1;

   int order[YSS_MAX_ZONE_TFS];
   int n = g_yss_cfg.zoneTfCount;
   for(int i = 0; i < n; i++)
      order[i] = i;
   for(int a = 0; a < n; a++)
     {
      for(int b = a + 1; b < n; b++)
        {
         if(PeriodSeconds(g_yss_cfg.zoneTfs[order[b]]) <
            PeriodSeconds(g_yss_cfg.zoneTfs[order[a]]))
           {
            const int tmp = order[a];
            order[a] = order[b];
            order[b] = tmp;
           }
        }
     }

   for(int oi = 0; oi < n; oi++)
     {
      const int tfIdx = order[oi];
      int slot = -1;
      SYssZone z;
      if(YssTouchedZoneAtTf(tfIdx, ask, bid, z, slot))
        {
         out = z;
         tfIdxOut = tfIdx;
         slotOut = slot;
         return true;
        }
     }
   return false;
  }

SYssZone YssNearestPending(void)
  {
   SYssZone best;
   YssZoneClear(best);
   datetime bestPeak = 0;

   // Prefer finest TF's freshest zone for the panel.
   int order[YSS_MAX_ZONE_TFS];
   int n = g_yss_cfg.zoneTfCount;
   for(int i = 0; i < n; i++)
      order[i] = i;
   for(int a = 0; a < n; a++)
     {
      for(int b = a + 1; b < n; b++)
        {
         if(PeriodSeconds(g_yss_cfg.zoneTfs[order[b]]) <
            PeriodSeconds(g_yss_cfg.zoneTfs[order[a]]))
           {
            const int tmp = order[a];
            order[a] = order[b];
            order[b] = tmp;
           }
        }
     }

   for(int oi = 0; oi < n; oi++)
     {
      const int tfIdx = order[oi];
      if(g_yss_zoneCount[tfIdx] <= 0)
         continue;
      SYssZone z = g_yss_zones[tfIdx][g_yss_zoneCount[tfIdx] - 1];
      if(!z.valid)
         continue;
      if(!best.valid || z.peakTime >= bestPeak)
        {
         best = z;
         bestPeak = z.peakTime;
         // First (finest) TF with a valid zone is enough for UI focus.
         break;
        }
     }
   return best;
  }

#endif
//+------------------------------------------------------------------+
