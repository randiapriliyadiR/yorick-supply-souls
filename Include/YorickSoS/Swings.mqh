//+------------------------------------------------------------------+
//| YorickSoS/Swings.mqh — fractal swings + BOS                      |
//+------------------------------------------------------------------+
#ifndef YORICKSOS_SWINGS_MQH
#define YORICKSOS_SWINGS_MQH

bool YssIsSwingHigh(const string symbol,
                    const ENUM_TIMEFRAMES tf,
                    const int shift,
                    const int strength)
  {
   if(strength < 1 || shift - strength < 0)
      return false;
   const double h = iHigh(symbol, tf, shift);
   if(h <= 0.0)
      return false;
   for(int k = 1; k <= strength; k++)
     {
      if(iHigh(symbol, tf, shift + k) >= h)
         return false;
      if(iHigh(symbol, tf, shift - k) >= h)
         return false;
     }
   return true;
  }

bool YssIsSwingLow(const string symbol,
                   const ENUM_TIMEFRAMES tf,
                   const int shift,
                   const int strength)
  {
   if(strength < 1 || shift - strength < 0)
      return false;
   const double l = iLow(symbol, tf, shift);
   if(l <= 0.0)
      return false;
   for(int k = 1; k <= strength; k++)
     {
      if(iLow(symbol, tf, shift + k) <= l)
         return false;
      if(iLow(symbol, tf, shift - k) <= l)
         return false;
     }
   return true;
  }

bool YssSwingHighBefore(const string symbol,
                        const ENUM_TIMEFRAMES tf,
                        const int baseShift,
                        const int strength,
                        const int lookback,
                        double &level,
                        datetime &when)
  {
   level = 0.0;
   when = 0;
   const int start = baseShift + strength;
   const int stop  = lookback - strength;
   if(start > stop)
      return false;
   for(int s = start; s <= stop; s++)
     {
      if(!YssIsSwingHigh(symbol, tf, s, strength))
         continue;
      level = iHigh(symbol, tf, s);
      when  = iTime(symbol, tf, s);
      return (level > 0.0 && when > 0);
     }
   return false;
  }

bool YssSwingLowBefore(const string symbol,
                       const ENUM_TIMEFRAMES tf,
                       const int baseShift,
                       const int strength,
                       const int lookback,
                       double &level,
                       datetime &when)
  {
   level = 0.0;
   when = 0;
   const int start = baseShift + strength;
   const int stop  = lookback - strength;
   if(start > stop)
      return false;
   for(int s = start; s <= stop; s++)
     {
      if(!YssIsSwingLow(symbol, tf, s, strength))
         continue;
      level = iLow(symbol, tf, s);
      when  = iTime(symbol, tf, s);
      return (level > 0.0 && when > 0);
     }
   return false;
  }

bool YssBosDemand(const string symbol,
                  const ENUM_TIMEFRAMES tf,
                  const int firstShift,
                  const int endShift,
                  const double swingHigh,
                  datetime &bosTime)
  {
   bosTime = 0;
   if(swingHigh <= 0.0 || firstShift < endShift)
      return false;
   for(int j = firstShift; j >= endShift; j--)
     {
      if(iClose(symbol, tf, j) > swingHigh)
        {
         bosTime = iTime(symbol, tf, j);
         return true;
        }
     }
   return false;
  }

bool YssBosSupply(const string symbol,
                  const ENUM_TIMEFRAMES tf,
                  const int firstShift,
                  const int endShift,
                  const double swingLow,
                  datetime &bosTime)
  {
   bosTime = 0;
   if(swingLow <= 0.0 || firstShift < endShift)
      return false;
   for(int j = firstShift; j >= endShift; j--)
     {
      if(iClose(symbol, tf, j) < swingLow)
        {
         bosTime = iTime(symbol, tf, j);
         return true;
        }
     }
   return false;
  }

#endif
//+------------------------------------------------------------------+
