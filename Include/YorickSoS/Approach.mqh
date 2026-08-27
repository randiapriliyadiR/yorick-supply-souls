//+------------------------------------------------------------------+
//| YorickSoS/Approach.mqh — slow vs sharp return into the zone      |
//+------------------------------------------------------------------+
#ifndef YORICKSOS_APPROACH_MQH
#define YORICKSOS_APPROACH_MQH

#include "Types.mqh"

ENUM_YSS_APPROACH YssClassifyApproach(const SYssCfg &cfg,
                                      const SYssZone &z,
                                      const double atr)
  {
   if(!z.valid || z.peakTime == 0 || atr <= 0.0)
      return YSS_APP_NA;

   const int peakShift = iBarShift(cfg.symbol, cfg.tf, z.peakTime, true);
   if(peakShift < 0)
      return YSS_APP_NA;

   int bars = 0;
   double maxRange = 0.0;
   bool sharpToward = false;

   for(int j = peakShift - 1; j >= 0; j--)
     {
      bars++;
      const double rng = iHigh(cfg.symbol, cfg.tf, j) - iLow(cfg.symbol, cfg.tf, j);
      if(rng > maxRange)
         maxRange = rng;
      const bool bear = (iClose(cfg.symbol, cfg.tf, j) < iOpen(cfg.symbol, cfg.tf, j));
      const bool toward = (z.dir > 0 ? bear : !bear);
      if(rng >= cfg.sharpAtr * atr && toward)
         sharpToward = true;
     }

   if(bars < cfg.minApproachBars)
      return YSS_APP_NA;
   if(sharpToward)
      return YSS_APP_SHARP;
   if(maxRange <= cfg.slowMaxAtr * atr)
      return YSS_APP_SLOW;
   return YSS_APP_MID;
  }

#endif
//+------------------------------------------------------------------+
