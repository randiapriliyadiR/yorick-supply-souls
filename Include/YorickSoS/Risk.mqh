//+------------------------------------------------------------------+
//| YorickSoS/Risk.mqh                                               |
//+------------------------------------------------------------------+
#ifndef YORICKSOS_RISK_MQH
#define YORICKSOS_RISK_MQH

#include "Types.mqh"

double YssNormalizePrice(const string symbol, const double price)
  {
   double tick = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick <= 0.0)
      tick = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(tick <= 0.0)
      return price;
   return MathRound(price / tick) * tick;
  }

double YssNormalizeLots(const string symbol, double lots)
  {
   const double minLot  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   const double maxLot  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double stepLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   if(stepLot <= 0.0)
      stepLot = 0.01;

   if(lots + 1e-12 < minLot)
      return 0.0;

   lots = MathFloor(lots / stepLot + 1e-12) * stepLot;
   lots = NormalizeDouble(lots, 8);
   if(lots + 1e-12 < minLot)
      return 0.0;
   if(lots > maxLot)
      lots = maxLot;
   return lots;
  }

double YssMinStopDistance(const string symbol)
  {
   const long   stopsLevel = SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const double point      = SymbolInfoDouble(symbol, SYMBOL_POINT);
   const double minDist    = (stopsLevel > 0 ? (double)stopsLevel * point : 0.0);
   const double spread     = SymbolInfoDouble(symbol, SYMBOL_ASK) - SymbolInfoDouble(symbol, SYMBOL_BID);
   return MathMax(minDist, spread);
  }

void YssAdjustStops(const string symbol,
                    const bool isBuy,
                    const double entry,
                    double &sl,
                    double &tp)
  {
   const double need = YssMinStopDistance(symbol);
   if(isBuy)
     {
      if(sl > 0.0 && entry - sl < need)
         sl = entry - need;
      if(tp > 0.0 && tp - entry < need)
         tp = entry + need;
     }
   else
     {
      if(sl > 0.0 && sl - entry < need)
         sl = entry + need;
      if(tp > 0.0 && entry - tp < need)
         tp = entry - need;
     }
   sl = YssNormalizePrice(symbol, sl);
   if(tp > 0.0)
      tp = YssNormalizePrice(symbol, tp);
  }

void YssFillZoneStops(SYssZone &z, const double slZoneMult)
  {
   const double h = z.zoneHigh - z.zoneLow;
   if(h <= 0.0)
      return;
   const double extra = MathMax(0.0, slZoneMult - 1.0) * h;
   if(z.dir > 0)
     {
      z.entry = z.zoneHigh;
      z.sl    = z.zoneLow - extra;
      z.tp    = z.impulseExtreme;
     }
   else
     {
      z.entry = z.zoneLow;
      z.sl    = z.zoneHigh + extra;
      z.tp    = z.impulseExtreme;
     }
  }

double YssLotsForRisk(const string symbol,
                      const double balance,
                      const double riskPct,
                      const double entry,
                      const double sl)
  {
   if(balance <= 0.0 || riskPct <= 0.0)
      return 0.0;

   const double tickSize  = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   const double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   if(tickSize <= 0.0 || tickValue <= 0.0)
      return 0.0;

   const double slDist = MathAbs(entry - sl);
   if(slDist < tickSize)
      return 0.0;

   const double ticks = slDist / tickSize;
   const double lossPerLot = ticks * tickValue;
   if(lossPerLot <= 0.0)
      return 0.0;

   const double riskMoney = balance * riskPct / 100.0;
   return YssNormalizeLots(symbol, riskMoney / lossPerLot);
  }

#endif
//+------------------------------------------------------------------+
