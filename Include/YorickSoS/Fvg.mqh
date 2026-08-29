//+------------------------------------------------------------------+
//| YorickSoS/Fvg.mqh — 3-candle FVG connected to zone candle        |
//+------------------------------------------------------------------+
#ifndef YORICKSOS_FVG_MQH
#define YORICKSOS_FVG_MQH

#include "Series.mqh"

// left = baseShift, mid = baseShift-1, right = baseShift-2
bool YssBullishFvgAtBase(const string symbol,
                         const ENUM_TIMEFRAMES tf,
                         const int baseShift,
                         double &top,
                         double &bot)
  {
   top = 0.0;
   bot = 0.0;
   if(baseShift < 2)
      return false;
   const double highLeft = YssH(symbol, tf, baseShift);
   const double lowRight = YssL(symbol, tf, baseShift - 2);
   if(lowRight > highLeft && highLeft > 0.0)
     {
      bot = highLeft;
      top = lowRight;
      return true;
     }
   return false;
  }

bool YssBearishFvgAtBase(const string symbol,
                         const ENUM_TIMEFRAMES tf,
                         const int baseShift,
                         double &top,
                         double &bot)
  {
   top = 0.0;
   bot = 0.0;
   if(baseShift < 2)
      return false;
   const double lowLeft  = YssL(symbol, tf, baseShift);
   const double highRight = YssH(symbol, tf, baseShift - 2);
   if(highRight < lowLeft && highRight > 0.0)
     {
      top = lowLeft;
      bot = highRight;
      return true;
     }
   return false;
  }

bool YssAnyBullishFvg(const string symbol,
                      const ENUM_TIMEFRAMES tf,
                      const int midShift,
                      double &top,
                      double &bot)
  {
   top = 0.0;
   bot = 0.0;
   if(midShift < 1)
      return false;
   const double highLeft = YssH(symbol, tf, midShift + 1);
   const double lowRight = YssL(symbol, tf, midShift - 1);
   if(lowRight > highLeft && highLeft > 0.0)
     {
      bot = highLeft;
      top = lowRight;
      return true;
     }
   return false;
  }

bool YssAnyBearishFvg(const string symbol,
                      const ENUM_TIMEFRAMES tf,
                      const int midShift,
                      double &top,
                      double &bot)
  {
   top = 0.0;
   bot = 0.0;
   if(midShift < 1)
      return false;
   const double lowLeft   = YssL(symbol, tf, midShift + 1);
   const double highRight = YssH(symbol, tf, midShift - 1);
   if(highRight < lowLeft && highRight > 0.0)
     {
      top = lowLeft;
      bot = highRight;
      return true;
     }
   return false;
  }

#endif
//+------------------------------------------------------------------+
