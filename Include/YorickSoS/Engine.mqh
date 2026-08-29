//+------------------------------------------------------------------+
//| YorickSoS/Engine.mqh                                             |
//+------------------------------------------------------------------+
#ifndef YORICKSOS_ENGINE_MQH
#define YORICKSOS_ENGINE_MQH

#include "Types.mqh"
#include "Risk.mqh"
#include "Orders.mqh"
#include "Zones.mqh"
#include "Approach.mqh"
#include "Trend.mqh"

bool YssCopyAtrHandle(const int handle, double &atr[])
  {
   const int n = g_yss_cfg.lookback + 2;
   ArraySetAsSeries(atr, true);
   if(CopyBuffer(handle, 0, 0, n, atr) < n)
      return false;
   if(ArraySize(atr) >= 2 && atr[1] > 0.0)
      g_yss_atrNow = atr[1];
   else if(ArraySize(atr) >= 1)
      g_yss_atrNow = atr[0];
   return (g_yss_atrNow > 0.0);
  }

bool YssCopyAtr(double &atr[])
  {
   if(g_hAtr != INVALID_HANDLE)
      return YssCopyAtrHandle(g_hAtr, atr);
   return false;
  }

double YssAtrNow(const double &atr[])
  {
   if(ArraySize(atr) < 2)
      return 0.0;
   if(atr[1] > 0.0)
      return atr[1];
   return atr[0];
  }

bool YssReady(void)
  {
   if(g_yss_cfg.zoneTfCount <= 0)
      return false;
   for(int i = 0; i < g_yss_cfg.zoneTfCount; i++)
     {
      const ENUM_TIMEFRAMES tf = g_yss_cfg.zoneTfs[i];
      if(g_hAtrZone[i] == INVALID_HANDLE)
         return false;
      if(BarsCalculated(g_hAtrZone[i]) < g_yss_cfg.atrPeriod + 5)
         return false;
      if(iBars(g_yss_cfg.symbol, tf) < g_yss_cfg.lookback)
         return false;
     }
   if(iBars(g_yss_cfg.symbol, g_yss_cfg.trendTf) < g_yss_cfg.lookback)
      return false;
   return true;
  }

bool YssNewBarTf(const ENUM_TIMEFRAMES tf, datetime &cache)
  {
   const datetime t = iTime(g_yss_cfg.symbol, tf, 0);
   if(t == 0 || t == cache)
      return false;
   cache = t;
   return true;
  }

double YssAtrForZoneTf(const ENUM_TIMEFRAMES zoneTf)
  {
   const int h = YssAtrHandleForTf(zoneTf);
   if(h == INVALID_HANDLE)
      return g_yss_atrNow;
   double atr[];
   ArraySetAsSeries(atr, true);
   if(CopyBuffer(h, 0, 0, 3, atr) >= 2 && atr[1] > 0.0)
      return atr[1];
   return g_yss_atrNow;
  }

void YssFillView(const double atr, const bool inTrade, const ulong ticket)
  {
   g_yss_view.atr = atr;
   g_yss_view.close = YssC(g_yss_cfg.symbol, g_yss_cfg.tf, 0);
   g_yss_view.balance = AccountInfoDouble(ACCOUNT_BALANCE);
   g_yss_view.equity  = AccountInfoDouble(ACCOUNT_EQUITY);
   g_yss_view.commissionPaid = g_yss_commissionPaid;
   g_yss_view.posDir = 0;
   g_yss_view.posLots = 0.0;
   g_yss_view.posSl = 0.0;
   g_yss_view.posTp = 0.0;
   g_yss_view.posProfit = 0.0;

   SYssZone z = YssNearestPending();
   if(inTrade && ticket != 0 && PositionSelectByTicket(ticket))
     {
      g_yss_view.state = YSS_IN_TRADE;
      g_yss_view.posDir = YssPosDir(ticket);
      g_yss_view.posLots = PositionGetDouble(POSITION_VOLUME);
      g_yss_view.posSl = PositionGetDouble(POSITION_SL);
      g_yss_view.posTp = PositionGetDouble(POSITION_TP);
      g_yss_view.posProfit = PositionGetDouble(POSITION_PROFIT)
                             + PositionGetDouble(POSITION_SWAP);
      z.dir = g_yss_view.posDir;
      z.sl = g_yss_view.posSl;
      z.tp = g_yss_view.posTp;
      z.valid = true;
     }
   else if(z.valid)
     {
      const ENUM_YSS_APPROACH app = YssClassifyApproach(g_yss_cfg, z, atr);
      g_yss_view.approach = app;
      if(app == YSS_APP_SHARP || app == YSS_APP_MID)
         g_yss_view.state = YSS_WAIT_SLOW;
      else
         g_yss_view.state = YSS_WAIT_RETURN;
     }
   else
     {
      g_yss_view.state = YSS_IDLE;
      g_yss_view.approach = YSS_APP_NA;
      if(g_yss_view.reason == "")
         g_yss_view.reason = "no fresh soul";
     }

   g_yss_view.zone = z;
   double entry = z.entry;
   double sl = z.sl;
   if(z.valid)
     {
      entry = (z.dir > 0
               ? SymbolInfoDouble(g_yss_cfg.symbol, SYMBOL_ASK)
               : SymbolInfoDouble(g_yss_cfg.symbol, SYMBOL_BID));
      sl = z.sl;
      double tp = z.tp;
      YssAdjustStops(g_yss_cfg.symbol, z.dir > 0, entry, sl, tp);
     }
   g_yss_view.nextLots = (z.valid
                          ? YssLotsForRisk(g_yss_cfg.symbol, g_yss_view.balance,
                                           g_yss_cfg.riskPct, entry, sl)
                          : 0.0);
   g_yss_view.riskMoney = g_yss_view.balance * g_yss_cfg.riskPct / 100.0;
  }

bool YssEnter(const SYssZone &signal, string &reason)
  {
   const string symbol = g_yss_cfg.symbol;
   if(g_yss_cfg.maxSpreadPoints > 0)
     {
      const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      const double spr = SymbolInfoDouble(symbol, SYMBOL_ASK)
                         - SymbolInfoDouble(symbol, SYMBOL_BID);
      if(point > 0.0 && spr / point > (double)g_yss_cfg.maxSpreadPoints)
        {
         reason = "spread too wide";
         return false;
        }
     }

   const int dir = signal.dir;
   double entry = (dir > 0
                   ? SymbolInfoDouble(symbol, SYMBOL_ASK)
                   : SymbolInfoDouble(symbol, SYMBOL_BID));
   double sl = signal.sl;
   double tp = signal.tp;

   if(dir > 0)
     {
      if(sl >= entry || tp <= entry)
        {
         reason = "demand stops invalid";
         return false;
        }
     }
   else
     {
      if(sl <= entry || tp >= entry)
        {
         reason = "supply stops invalid";
         return false;
        }
     }

   YssAdjustStops(symbol, dir > 0, entry, sl, tp);

   // RR gate uses raw zone geometry (before commission bake-in).
   if(g_yss_cfg.requireMinRr && g_yss_cfg.minRiskReward > 0.0)
     {
      const double risk = MathAbs(entry - sl);
      const double reward = MathAbs(tp - entry);
      if(risk <= 0.0 || reward / risk + 1e-12 < g_yss_cfg.minRiskReward)
        {
         reason = "rr too low";
         return false;
        }
     }

   const double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double lots = YssLotsForRisk(symbol, balance, g_yss_cfg.riskPct, entry, sl);
   if(lots <= 0.0)
     {
      reason = "lot size 0";
      return false;
     }

   // Bake open+close commission into SL/TP after RR/lot sizing so tester equity
   // reflects Exness Raw fees without wiping the MinRR gate.
   YssApplyCommissionToStops(symbol, dir > 0, entry, lots, sl, tp);
   YssAdjustStops(symbol, dir > 0, entry, sl, tp);
   if(dir > 0)
     {
      if(sl >= entry || tp <= entry)
        {
         reason = "demand stops invalid after commission";
         return false;
        }
     }
   else
     {
      if(sl <= entry || tp >= entry)
        {
         reason = "supply stops invalid after commission";
         return false;
        }
     }

   const string cmt = YssPosCommentTag(signal.zoneTf, dir);
   if(!YssOpen(symbol, dir, lots, sl, tp, cmt))
      return false;

   const double comm = YssCommissionMoney(lots);
   if(comm > 0.0)
     {
      g_yss_commissionPaid += comm;
      Print("YSS debug commission: lots=", DoubleToString(lots, 2),
            " round-trip≈$", DoubleToString(comm, 2),
            " ($", DoubleToString(g_yss_cfg.commissionPerLot, 2), "/lot/side)",
            " total≈$", DoubleToString(g_yss_commissionPaid, 2));
     }

   reason = (dir > 0 ? "demand touch + slow return" : "supply touch + slow return");
   return true;
  }

void YssTryEnterOne(const int tfIdx, const double ask, const double bid)
  {
   if(tfIdx < 0 || tfIdx >= g_yss_cfg.zoneTfCount)
      return;
   const ENUM_TIMEFRAMES ztf = g_yss_cfg.zoneTfs[tfIdx];
   if(YssHasOpenBlock(g_yss_cfg.symbol, g_yss_cfg.magic, ztf))
      return;

   SYssZone z;
   int slot = -1;
   if(!YssTouchedZoneAtTf(tfIdx, ask, bid, z, slot))
      return;

   if(!YssSeriesLoad(g_yss_cfg.symbol, z.zoneTf, g_yss_cfg.lookback + 5))
     {
      g_yss_view.reason = "zone series fail";
      return;
     }
   const double zoneAtr = YssAtrForZoneTf(z.zoneTf);
   const ENUM_YSS_APPROACH app = YssClassifyApproach(g_yss_cfg, z, zoneAtr);
   g_yss_view.approach = app;

   if(!YssSeriesLoad(g_yss_cfg.symbol, g_yss_cfg.trendTf, g_yss_cfg.lookback + 5))
     {
      g_yss_view.reason = "trend series fail";
      return;
     }
   const int trendBias = YssTrendBias(g_yss_cfg.symbol, g_yss_cfg.trendTf,
                                      g_yss_cfg.swingStrength, g_yss_cfg.lookback);
   if(!YssTrendGateAllows(z.dir, trendBias, g_yss_cfg.requireTrend))
     {
      g_yss_view.state = YSS_WAIT_RETURN;
      g_yss_view.reason = (trendBias > 0 ? "trend up, skip supply"
                           : (trendBias < 0 ? "trend down, skip demand" : "trend unclear"));
      YssUsedAdd(z.baseTime, z.zoneTf);
      YssZoneRemoveAt(tfIdx, slot);
      return;
     }

   if(g_yss_cfg.requireSlow && app != YSS_APP_SLOW)
     {
      g_yss_view.state = YSS_WAIT_SLOW;
      g_yss_view.reason = (app == YSS_APP_SHARP ? "sharp return, skip" : "return not slow");
      YssUsedAdd(z.baseTime, z.zoneTf);
      YssZoneRemoveAt(tfIdx, slot);
      return;
     }

   if(YssEnter(z, g_yss_view.reason))
     {
      YssUsedAdd(z.baseTime, z.zoneTf);
      YssZoneRemoveAt(tfIdx, slot);
      g_yss_view.state = YSS_IN_TRADE;
      g_yss_view.zone = z;
     }
  }

void YssTryEnter(const double atr)
  {
   const double ask = SymbolInfoDouble(g_yss_cfg.symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(g_yss_cfg.symbol, SYMBOL_BID);

   if(!g_yss_cfg.onePosPerTf)
     {
      ulong ticket = 0;
      if(YssSelectPosition(g_yss_cfg.symbol, g_yss_cfg.magic, ticket))
         return;
      // Prefer finer TF when only one global slot is allowed.
      int order[YSS_MAX_ZONE_TFS];
      const int n = g_yss_cfg.zoneTfCount;
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
         const int before = YssCountOurPositions(g_yss_cfg.symbol, g_yss_cfg.magic);
         YssTryEnterOne(order[oi], ask, bid);
         if(YssCountOurPositions(g_yss_cfg.symbol, g_yss_cfg.magic) > before)
            return;
        }
      return;
     }

   // One position per entry TF — all books may trade in parallel.
   for(int tfIdx = 0; tfIdx < g_yss_cfg.zoneTfCount; tfIdx++)
      YssTryEnterOne(tfIdx, ask, bid);
  }

void YssManageGuard(const ulong ticket)
  {
   if(!g_yss_cfg.useGuard)
      return;
   if(ticket == 0 || !PositionSelectByTicket(ticket))
      return;

   const int gs = YssGuardSlotForTicket(ticket);
   if(gs < 0)
      return;

   const string symbol = PositionGetString(POSITION_SYMBOL);
   const bool   isBuy  = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
   const double entry  = PositionGetDouble(POSITION_PRICE_OPEN);
   const double curSl  = PositionGetDouble(POSITION_SL);
   const double bid    = SymbolInfoDouble(symbol, SYMBOL_BID);
   const double ask    = SymbolInfoDouble(symbol, SYMBOL_ASK);
   const double px     = (isBuy ? bid : ask);

   if(ticket != g_yss_guards[gs].ticket)
     {
      g_yss_guards[gs].ticket = ticket;
      g_yss_guards[gs].r = MathAbs(entry - curSl);
      g_yss_guards[gs].best = px;
      g_yss_guards[gs].beDone = false;
     }

   if(g_yss_guards[gs].r <= 0.0)
      return;

   if(isBuy)
      g_yss_guards[gs].best = MathMax(g_yss_guards[gs].best, px);
   else
     {
      if(g_yss_guards[gs].best <= 0.0)
         g_yss_guards[gs].best = px;
      else
         g_yss_guards[gs].best = MathMin(g_yss_guards[gs].best, px);
     }

   const double fav = (isBuy
                       ? (g_yss_guards[gs].best - entry)
                       : (entry - g_yss_guards[gs].best));
   double newSl = curSl;

   if(!g_yss_guards[gs].beDone && fav + 1e-12 >= g_yss_cfg.beTriggerR * g_yss_guards[gs].r)
     {
      newSl = entry;
      g_yss_guards[gs].beDone = true;
      g_yss_view.reason = "guard BEP";
     }

   if(fav + 1e-12 >= g_yss_cfg.trailStartR * g_yss_guards[gs].r)
     {
      const double trailSl = (isBuy
                              ? g_yss_guards[gs].best - g_yss_cfg.trailDistR * g_yss_guards[gs].r
                              : g_yss_guards[gs].best + g_yss_cfg.trailDistR * g_yss_guards[gs].r);
      if(isBuy)
         newSl = MathMax(newSl, trailSl);
      else
        {
         if(newSl <= 0.0)
            newSl = trailSl;
         else
            newSl = MathMin(newSl, trailSl);
        }
      g_yss_view.reason = "guard trail";
     }

   if(g_yss_guards[gs].beDone)
     {
      if(isBuy)
         newSl = MathMax(newSl, entry);
      else if(newSl <= 0.0 || newSl > entry)
         newSl = entry;
     }

   if(MathAbs(newSl - curSl) > 1e-12)
      YssModifySl(ticket, isBuy, newSl);
  }

void YssManageAllGuards(void)
  {
   if(!g_yss_cfg.useGuard)
     {
      YssGuardsResetAll();
      return;
     }

   bool live[YSS_MAX_ZONE_TFS];
   for(int z = 0; z < YSS_MAX_ZONE_TFS; z++)
      live[z] = false;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != g_yss_cfg.symbol)
         continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) != g_yss_cfg.magic)
         continue;
      YssManageGuard(t);
      const int gs = YssGuardSlotForTicket(t);
      if(gs >= 0)
         live[gs] = true;
     }

   for(int g = 0; g < YSS_MAX_ZONE_TFS; g++)
     {
      if(g_yss_guards[g].ticket != 0 && !live[g])
        {
         g_yss_guards[g].ticket = 0;
         g_yss_guards[g].r = 0.0;
         g_yss_guards[g].best = 0.0;
         g_yss_guards[g].beDone = false;
        }
     }
  }

void YssEngineStep(const bool newBar)
  {
   if(!YssReady())
     {
      g_yss_view.reason = "warming up";
      return;
     }

   bool rescan = newBar || g_yss_needScan;
   for(int i = 0; i < g_yss_cfg.zoneTfCount; i++)
     {
      if(YssNewBarTf(g_yss_cfg.zoneTfs[i], g_yss_lastBarZone[i]))
         rescan = true;
     }

   if(rescan)
     {
      if(!YssCopyAtr(g_yss_atrBuf))
        {
         g_yss_view.reason = "atr copy fail";
         return;
        }
      YssRescanAllZones();
      YssInvalidatePending();
      g_yss_needScan = false;
     }
   else if(g_yss_atrNow <= 0.0)
     {
      if(!YssCopyAtr(g_yss_atrBuf))
        {
         g_yss_needScan = true;
         return;
        }
     }

   if(YssZoneTotalCount() > 0)
      YssTryEnter(g_yss_atrNow);

   g_yss_openCount = YssCountOurPositions(g_yss_cfg.symbol, g_yss_cfg.magic);
   g_yss_inTrade = (g_yss_openCount > 0);
   g_yss_posTicket = 0;
   if(g_yss_inTrade)
      YssSelectPosition(g_yss_cfg.symbol, g_yss_cfg.magic, g_yss_posTicket);
   YssManageAllGuards();
  }

#endif
//+------------------------------------------------------------------+
