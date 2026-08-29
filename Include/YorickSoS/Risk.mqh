//+------------------------------------------------------------------+
//| YorickSoS/Risk.mqh                                               |
//+------------------------------------------------------------------+
#ifndef YORICKSOS_RISK_MQH
#define YORICKSOS_RISK_MQH

#include "Types.mqh"

bool YssQualityRiskOn(const SYssCfg &cfg)
  {
   return (cfg.qualityMode == YSS_QMODE_A || cfg.qualityMode == YSS_QMODE_C);
  }

int YssQualityMax(const SYssCfg &cfg)
  {
   if(cfg.qualityMode == YSS_QMODE_A || cfg.qualityMode == YSS_QMODE_C)
      return 2;
   return 0;
  }

// Mode A: FVG + BOS soft points.
int YssQualityScoreA(const bool hasFvg, const bool hasBos)
  {
   return (hasFvg ? 1 : 0) + (hasBos ? 1 : 0);
  }

// Mode C: extras only (FVG/BOS already hard). Strong impulse + pure slow.
int YssQualityScoreC(const SYssCfg &cfg,
                     const SYssZone &z,
                     const ENUM_YSS_APPROACH app,
                     const double approachMaxRange,
                     const double atr)
  {
   int score = 0;
   // Strong surge: ≥1.75× minimum impulse ATR threshold
   if(z.impulseAtrRatio + 1e-12 >= cfg.impulseAtrMult * 1.75)
      score++;
   // Pure slow return: slow gate already passed; max bar ≤ half of slow ceiling
   if(app == YSS_APP_SLOW && atr > 0.0 &&
      approachMaxRange + 1e-12 <= cfg.slowMaxAtr * atr * 0.5)
      score++;
   return score;
  }

double YssRiskPctFromScore(const SYssCfg &cfg, const int score, const int maxScore)
  {
   if(!YssQualityRiskOn(cfg) || maxScore <= 0)
      return cfg.riskPct;

   double lo = cfg.riskMinPct;
   double hi = cfg.riskMaxPct;
   if(lo <= 0.0)
      lo = cfg.riskPct;
   if(hi < lo)
      hi = lo;

   const int s = MathMax(0, MathMin(score, maxScore));
   return lo + (hi - lo) * ((double)s / (double)maxScore);
  }

void YssApplyZoneQuality(const SYssCfg &cfg, SYssZone &z)
  {
   // Build-time preview (A uses FVG/BOS; C fills score later at entry).
   z.qualityMax = YssQualityMax(cfg);
   if(cfg.qualityMode == YSS_QMODE_A)
     {
      z.qualityScore = YssQualityScoreA(z.hasFvg, z.hasBos);
      z.riskPctUsed = YssRiskPctFromScore(cfg, z.qualityScore, z.qualityMax);
      return;
     }
   if(cfg.qualityMode == YSS_QMODE_C)
     {
      z.qualityScore = 0;
      z.riskPctUsed = cfg.riskMinPct > 0.0 ? cfg.riskMinPct : cfg.riskPct;
      return;
     }
   z.qualityScore = 0;
   z.qualityMax = 0;
   z.riskPctUsed = cfg.riskPct;
  }

void YssFinalizeZoneQuality(const SYssCfg &cfg,
                            SYssZone &z,
                            const ENUM_YSS_APPROACH app,
                            const double approachMaxRange,
                            const double atr)
  {
   z.qualityMax = YssQualityMax(cfg);
   if(cfg.qualityMode == YSS_QMODE_A)
     {
      z.qualityScore = YssQualityScoreA(z.hasFvg, z.hasBos);
     }
   else if(cfg.qualityMode == YSS_QMODE_C)
     {
      z.qualityScore = YssQualityScoreC(cfg, z, app, approachMaxRange, atr);
     }
   else
     {
      z.qualityScore = 0;
      z.qualityMax = 0;
      z.riskPctUsed = cfg.riskPct;
      return;
     }
   z.riskPctUsed = YssRiskPctFromScore(cfg, z.qualityScore, z.qualityMax);
  }

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

bool YssCommissionActive(void)
  {
   return (g_yss_cfg.simCommission &&
           g_yss_cfg.commissionPerLot > 0.0 &&
           (bool)MQLInfoInteger(MQL_TESTER));
  }

double YssCommissionMoney(const double lots)
  {
   if(!YssCommissionActive() || lots <= 0.0)
      return 0.0;
   return 2.0 * g_yss_cfg.commissionPerLot * lots; // open + close
  }

// USD commission per lot per side → price distance (independent of lot size).
double YssCommissionPricePerSide(const string symbol)
  {
   if(!YssCommissionActive())
      return 0.0;
   const double tickSize  = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   const double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   if(tickSize <= 0.0 || tickValue <= 0.0)
      return 0.0;
   return g_yss_cfg.commissionPerLot * tickSize / tickValue;
  }

// Bake open+close commission into SL/TP so tester equity reflects Exness Raw fees.
// Uses OrderCalcProfit so price distance matches the symbol's contract (custom ticks too).
void YssApplyCommissionToStops(const string symbol,
                               const bool isBuy,
                               const double entry,
                               const double lots,
                               double &sl,
                               double &tp)
  {
   if(!YssCommissionActive() || lots <= 0.0 || entry <= 0.0)
      return;

   const double money = YssCommissionMoney(lots); // round-trip USD
   if(money <= 0.0)
      return;

   double profit1 = 0.0;
   const ENUM_ORDER_TYPE otype = (isBuy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
   const double px2 = (isBuy ? entry + 1.0 : entry - 1.0);
   if(!OrderCalcProfit(otype, symbol, lots, entry, px2, profit1) || MathAbs(profit1) < 1e-8)
     {
      const double tickSize  = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
      const double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
      if(tickSize <= 0.0 || tickValue <= 0.0)
         return;
      const double d = money * tickSize / (lots * tickValue);
      if(isBuy) { if(sl > 0.0) sl -= d; if(tp > 0.0) tp -= d; }
      else      { if(sl > 0.0) sl += d; if(tp > 0.0) tp += d; }
      return;
     }

   const double d = money / MathAbs(profit1);
   if(isBuy)
     {
      if(sl > 0.0) sl -= d;
      if(tp > 0.0) tp -= d;
     }
   else
     {
      if(sl > 0.0) sl += d;
      if(tp > 0.0) tp += d;
     }
  }

#endif
//+------------------------------------------------------------------+
