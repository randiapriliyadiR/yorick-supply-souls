//+------------------------------------------------------------------+
//| YorickSoS/ChartView.mqh                                          |
//+------------------------------------------------------------------+
#ifndef YORICKSOS_CHARTVIEW_MQH
#define YORICKSOS_CHARTVIEW_MQH

#include "Types.mqh"

#define YSS_SL_LINE "YSS_SL_LINE"
#define YSS_TP_LINE "YSS_TP_LINE"

bool YssChartAdd(const int handle)
  {
   if(handle == INVALID_HANDLE)
      return false;
   if(ChartIndicatorAdd(0, 0, handle))
      return true;
   const uint err = GetLastError();
   if(err == 4114)
      return true;
   Print("YSS: ChartIndicatorAdd failed ", err);
   return false;
  }

void YssChartAttach(void)
  {
   if(!YssShowUi())
      return;
   YssChartAdd(g_hStruct);
   YssChartAdd(g_hFvg);
   YssChartAdd(g_hZones);
  }

void YssChartDetach(void)
  {
   ChartIndicatorDelete(0, 0, "Yorick Structure");
   ChartIndicatorDelete(0, 0, "Yorick FVG");
   ChartIndicatorDelete(0, 0, "Yorick Zones");
   ObjectDelete(0, YSS_SL_LINE);
   ObjectDelete(0, YSS_TP_LINE);
  }

void YssHLine(const string name, const double price, const color clr)
  {
   if(price <= 0.0)
     {
      ObjectDelete(0, name);
      return;
     }
   if(ObjectFind(0, name) < 0)
     {
      ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, name, OBJPROP_BACK, true);
     }
   ObjectSetDouble(0, name, OBJPROP_PRICE, price);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
  }

void YssChartLevels(const double sl, const double tp, const int dir)
  {
   if(!YssShowUi())
      return;
   if(dir == 0)
     {
      ObjectDelete(0, YSS_SL_LINE);
      ObjectDelete(0, YSS_TP_LINE);
      return;
     }
   YssHLine(YSS_SL_LINE, sl, clrCrimson);
   YssHLine(YSS_TP_LINE, tp, clrDodgerBlue);
  }

#endif
//+------------------------------------------------------------------+
