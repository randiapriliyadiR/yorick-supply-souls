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
   return (iClose(symbol, tf, shift) < iOpen(symbol, tf, shift));
  }

bool YssCandleBull(const string symbol, const ENUM_TIMEFRAMES tf, const int shift)
  {
   return (iClose(symbol, tf, shift) > iOpen(symbol, tf, shift));
  }

double YssBody(const string symbol, const ENUM_TIMEFRAMES tf, const int shift)
  {
   return MathAbs(iClose(symbol, tf, shift) - iOpen(symbol, tf, shift));
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

   const double zH = iHigh(symbol, tf, baseShift);
   const double zL = iLow(symbol, tf, baseShift);
   endShift = first;
   maxBody = 0.0;
   runExtreme = (dir > 0 ? iHigh(symbol, tf, first) : iLow(symbol, tf, first));

   for(int j = first; j >= 1; j--)
     {
      if(first - j + 1 > maxBars)
         break;

      const double body = YssBody(symbol, tf, j);
      if(body > maxBody)
         maxBody = body;

      if(dir > 0)
        {
         if(iHigh(symbol, tf, j) > runExtreme)
            runExtreme = iHigh(symbol, tf, j);
         if(j < first && iLow(symbol, tf, j) <= zH)
            break;
        }
      else
        {
         if(iLow(symbol, tf, j) < runExtreme)
            runExtreme = iLow(symbol, tf, j);
         if(j < first && iHigh(symbol, tf, j) >= zL)
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
         if(iHigh(symbol, tf, j) >= iHigh(symbol, tf, peak))
            peak = j;
        }
      else
        {
         if(iLow(symbol, tf, j) <= iLow(symbol, tf, peak))
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
         if(iLow(symbol, tf, j) <= z.zoneHigh)
            return true;
        }
      else
        {
         if(iHigh(symbol, tf, j) >= z.zoneLow)
            return true;
        }
     }
   return false;
  }

bool YssClosedThrough(const string symbol,
                      const ENUM_TIMEFRAMES tf,
                      const SYssZone &z)
  {
   const double c1 = iClose(symbol, tf, 1);
   if(z.dir > 0)
      return (c1 < z.zoneLow);
   return (c1 > z.zoneHigh);
  }

bool YssBuildZoneAt(const SYssCfg &cfg,
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
   const ENUM_TIMEFRAMES tf = cfg.tf;

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

   const double zH = iHigh(symbol, tf, baseShift);
   const double zL = iLow(symbol, tf, baseShift);
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
   z.baseTime = iTime(symbol, tf, baseShift);
   z.peakTime = iTime(symbol, tf, peak);
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

int YssFindZoneIndex(const datetime baseTime)
  {
   if(baseTime == 0)
      return -1;
   for(int i = 0; i < g_yss_zoneCount; i++)
     {
      if(g_yss_zones[i].baseTime == baseTime)
         return i;
     }
   return -1;
  }

void YssZonePush(const SYssZone &z)
  {
   const int existing = YssFindZoneIndex(z.baseTime);
   if(existing >= 0)
     {
      g_yss_zones[existing] = z;
      return;
     }
   if(g_yss_zoneCount >= YSS_MAX_ZONES)
     {
      for(int i = 1; i < YSS_MAX_ZONES; i++)
         g_yss_zones[i - 1] = g_yss_zones[i];
      g_yss_zoneCount = YSS_MAX_ZONES - 1;
     }
   g_yss_zones[g_yss_zoneCount++] = z;
  }

void YssZoneRemoveAt(const int idx)
  {
   if(idx < 0 || idx >= g_yss_zoneCount)
      return;
   for(int i = idx + 1; i < g_yss_zoneCount; i++)
      g_yss_zones[i - 1] = g_yss_zones[i];
   g_yss_zoneCount--;
  }

void YssScanZones(const double &atr[])
  {
   const SYssCfg cfg = g_yss_cfg;
   const int need = cfg.lookback;
   if(ArraySize(atr) < need)
      return;

   SYssZone kept[];
   ArrayResize(kept, 0);

   for(int b = 3; b <= need - cfg.swingStrength - 1; b++)
     {
      const datetime bt = iTime(cfg.symbol, cfg.tf, b);
      if(bt == 0 || YssUsedContains(bt))
         continue;
      const double a = atr[b];
      if(a <= 0.0)
         continue;

      SYssZone z;
      if(YssBuildZoneAt(cfg, b, 1, a, z, true))
        {
         const int n = ArraySize(kept);
         ArrayResize(kept, n + 1);
         kept[n] = z;
        }
      else if(YssBuildZoneAt(cfg, b, -1, a, z, true))
        {
         const int n = ArraySize(kept);
         ArrayResize(kept, n + 1);
         kept[n] = z;
        }
     }

   g_yss_zoneCount = 0;
   const int total = ArraySize(kept);
   const int start = MathMax(0, total - YSS_MAX_ZONES);
   for(int i = start; i < total; i++)
      YssZonePush(kept[i]);
  }

void YssInvalidatePending(void)
  {
   for(int i = g_yss_zoneCount - 1; i >= 0; i--)
     {
      if(!g_yss_zones[i].valid)
        {
         YssZoneRemoveAt(i);
         continue;
        }
      if(YssClosedThrough(g_yss_cfg.symbol, g_yss_cfg.tf, g_yss_zones[i]))
        {
         YssUsedAdd(g_yss_zones[i].baseTime);
         YssZoneRemoveAt(i);
        }
     }
  }

int YssTouchedZoneIndex(const double ask, const double bid)
  {
   for(int i = g_yss_zoneCount - 1; i >= 0; i--)
     {
      SYssZone z = g_yss_zones[i];
      if(!z.valid)
         continue;
      if(z.dir > 0)
        {
         if(ask <= z.zoneHigh && bid >= z.zoneLow)
            return i;
         if(ask < z.zoneLow)
           {
            YssUsedAdd(z.baseTime);
            YssZoneRemoveAt(i);
           }
        }
      else
        {
         if(bid >= z.zoneLow && ask <= z.zoneHigh)
            return i;
         if(bid > z.zoneHigh)
           {
            YssUsedAdd(z.baseTime);
            YssZoneRemoveAt(i);
           }
        }
     }
   return -1;
  }

SYssZone YssNearestPending(void)
  {
   SYssZone z;
   YssZoneClear(z);
   if(g_yss_zoneCount <= 0)
      return z;
   return g_yss_zones[g_yss_zoneCount - 1];
  }

#endif
//+------------------------------------------------------------------+
