//+------------------------------------------------------------------+
//| YorickSoS/Orders.mqh                                             |
//+------------------------------------------------------------------+
#ifndef YORICKSOS_ORDERS_MQH
#define YORICKSOS_ORDERS_MQH

#include <Trade/Trade.mqh>
#include "Types.mqh"
#include "Risk.mqh"

CTrade g_yss_trade;

ENUM_ORDER_TYPE_FILLING YssFilling(const string symbol)
  {
   const long mode = SymbolInfoInteger(symbol, SYMBOL_FILLING_MODE);
   if((mode & SYMBOL_FILLING_IOC) == SYMBOL_FILLING_IOC)
      return ORDER_FILLING_IOC;
   if((mode & SYMBOL_FILLING_FOK) == SYMBOL_FILLING_FOK)
      return ORDER_FILLING_FOK;
   return ORDER_FILLING_RETURN;
  }

void YssOrdersInit(const ulong magic, const ulong deviation)
  {
   g_yss_trade.SetExpertMagicNumber((uint)magic);
   g_yss_trade.SetDeviationInPoints((uint)deviation);
   g_yss_trade.SetTypeFilling(YssFilling(_Symbol));
  }

bool YssSelectPosition(const string symbol, const ulong magic, ulong &ticket)
  {
   ticket = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != symbol)
         continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      ticket = t;
      return true;
     }
   return false;
  }

int YssPosDir(const ulong ticket)
  {
   if(!PositionSelectByTicket(ticket))
      return 0;
   const long type = PositionGetInteger(POSITION_TYPE);
   if(type == POSITION_TYPE_BUY)
      return 1;
   if(type == POSITION_TYPE_SELL)
      return -1;
   return 0;
  }

bool YssOpen(const string symbol,
             const int dir,
             const double lots,
             const double sl,
             const double tp,
             const string comment)
  {
   g_yss_trade.SetTypeFilling(YssFilling(symbol));
   const bool ok = (dir > 0)
                   ? g_yss_trade.Buy(lots, symbol, 0.0, sl, tp, comment)
                   : g_yss_trade.Sell(lots, symbol, 0.0, sl, tp, comment);
   if(!ok)
      Print("YSS: order failed ", g_yss_trade.ResultRetcode(), " ",
            g_yss_trade.ResultRetcodeDescription());
   return ok;
  }

#endif
//+------------------------------------------------------------------+
