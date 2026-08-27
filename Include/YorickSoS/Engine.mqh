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

bool YssCopyAtr(double &atr[])
  {
   const int n = g_yss_cfg.lookback + 2;
   ArraySetAsSeries(atr, true);
   if(CopyBuffer(g_hAtr, 0, 0, n, atr) < n)
      return false;
   return true;
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
   if(g_hAtr == INVALID_HANDLE)
      return false;
   if(BarsCalculated(g_hAtr) < g_yss_cfg.atrPeriod + 5)
      return false;
   if(iBars(g_yss_cfg.symbol, g_yss_cfg.tf) < g_yss_cfg.lookback)
      return false;
   return true;
  }

void YssFillView(const double atr, const bool inTrade, const ulong ticket)
  {
   g_yss_view.atr = atr;
   g_yss_view.close = iClose(g_yss_cfg.symbol, g_yss_cfg.tf, 0);
   g_yss_view.balance = AccountInfoDouble(ACCOUNT_BALANCE);
   g_yss_view.equity  = AccountInfoDouble(ACCOUNT_EQUITY);
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
   const double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   const double lots = YssLotsForRisk(symbol, balance, g_yss_cfg.riskPct, entry, sl);
   if(lots <= 0.0)
     {
      reason = "lot size 0";
      return false;
     }

   const string cmt = (dir > 0 ? "YSS demand" : "YSS supply");
   if(!YssOpen(symbol, dir, lots, sl, tp, cmt))
      return false;

   reason = (dir > 0 ? "demand touch + slow return" : "supply touch + slow return");
   return true;
  }

void YssTryEnter(const double atr)
  {
   ulong ticket = 0;
   if(YssSelectPosition(g_yss_cfg.symbol, g_yss_cfg.magic, ticket))
      return;

   const double ask = SymbolInfoDouble(g_yss_cfg.symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(g_yss_cfg.symbol, SYMBOL_BID);
   const int idx = YssTouchedZoneIndex(ask, bid);
   if(idx < 0)
      return;

   SYssZone z = g_yss_zones[idx];
   const ENUM_YSS_APPROACH app = YssClassifyApproach(g_yss_cfg, z, atr);
   g_yss_view.approach = app;

   if(g_yss_cfg.requireSlow && app != YSS_APP_SLOW)
     {
      g_yss_view.state = YSS_WAIT_SLOW;
      g_yss_view.reason = (app == YSS_APP_SHARP ? "sharp return, skip" : "return not slow");
      YssUsedAdd(z.baseTime);
      YssZoneRemoveAt(idx);
      return;
     }

   if(YssEnter(z, g_yss_view.reason))
     {
      YssUsedAdd(z.baseTime);
      YssZoneRemoveAt(idx);
      g_yss_view.state = YSS_IN_TRADE;
      g_yss_view.zone = z;
     }
  }

void YssEngineStep(const bool newBar)
  {
   if(!YssReady())
     {
      g_yss_view.reason = "warming up";
      return;
     }

   double atr[];
   if(!YssCopyAtr(atr))
     {
      g_yss_view.reason = "atr copy fail";
      return;
     }

   if(newBar)
     {
      YssScanZones(atr);
      YssInvalidatePending();
     }

   YssTryEnter(YssAtrNow(atr));

   ulong ticket = 0;
   const bool inTrade = YssSelectPosition(g_yss_cfg.symbol, g_yss_cfg.magic, ticket);
   YssFillView(YssAtrNow(atr), inTrade, ticket);
  }

#endif
//+------------------------------------------------------------------+
