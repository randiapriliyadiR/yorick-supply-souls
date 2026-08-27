//+------------------------------------------------------------------+
//| YorickSoS/Fvg.mqh — 3-candle FVG connected to zone candle        |
//+------------------------------------------------------------------+
#ifndef YORICKSOS_FVG_MQH
#define YORICKSOS_FVG_MQH

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
   const double highLeft = iHigh(symbol, tf, baseShift);
   const double lowRight = iLow(symbol, tf, baseShift - 2);
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
   const double lowLeft  = iLow(symbol, tf, baseShift);
   const double highRight = iHigh(symbol, tf, baseShift - 2);
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
   const double highLeft = iHigh(symbol, tf, midShift + 1);
   const double lowRight = iLow(symbol, tf, midShift - 1);
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
   const double lowLeft   = iLow(symbol, tf, midShift + 1);
   const double highRight = iHigh(symbol, tf, midShift - 1);
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
