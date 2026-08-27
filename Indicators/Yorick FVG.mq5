//+------------------------------------------------------------------+
//|                                                 Yorick FVG.mq5   |
//|                                                 Randi Apriliyadi |
//|                              https://github.com/randiapriliyadiR |
//+------------------------------------------------------------------+
#property copyright "Randi Apriliyadi"
#property link      "https://github.com/randiapriliyadiR"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_label1  "Yorick FVG"
#property indicator_type1   DRAW_NONE
#property tester_everytick_calculate

#include <YorickSoS/Fvg.mqh>

input int InpLookback = 200;  // Bars to map

double g_dummy[];
#define YSS_FVG_PFX "YSS_FVG_"

void YssFvgClear(void)
  {
   ObjectsDeleteAll(0, YSS_FVG_PFX);
  }

void YssFvgBox(const string key,
               const datetime t1,
               const datetime t2,
               const double top,
               const double bot,
               const color clr)
  {
   const string n = YSS_FVG_PFX + key;
   if(ObjectFind(0, n) < 0)
     {
      ObjectCreate(0, n, OBJ_RECTANGLE, 0, t1, top, t2, bot);
      ObjectSetInteger(0, n, OBJPROP_FILL, true);
      ObjectSetInteger(0, n, OBJPROP_BACK, true);
      ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, n, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, n, OBJPROP_WIDTH, 1);
     }
   ObjectSetInteger(0, n, OBJPROP_TIME, t1);
   ObjectSetDouble(0, n, OBJPROP_PRICE, top);
   ObjectSetInteger(0, n, OBJPROP_TIME, 1, t2);
   ObjectSetDouble(0, n, OBJPROP_PRICE, 1, bot);
   ObjectSetInteger(0, n, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, n, OBJPROP_BGCOLOR, clr);
  }

int OnInit()
  {
   if(InpLookback < 20)
      return(INIT_PARAMETERS_INCORRECT);
   SetIndexBuffer(0, g_dummy, INDICATOR_CALCULATIONS);
   IndicatorSetString(INDICATOR_SHORTNAME, "Yorick FVG");
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   YssFvgClear();
  }

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
   if(rates_total < InpLookback)
      return(0);
   if(prev_calculated == rates_total)
      return(rates_total);

   YssFvgClear();
   const int last = MathMin(InpLookback, rates_total - 3);
   int drawn = 0;
   const datetime nowT = iTime(_Symbol, PERIOD_CURRENT, 0);

   for(int mid = 2; mid <= last && drawn < 40; mid++)
     {
      double top = 0.0, bot = 0.0;
      const datetime tLeft = iTime(_Symbol, PERIOD_CURRENT, mid + 1);
      if(YssAnyBullishFvg(_Symbol, PERIOD_CURRENT, mid, top, bot))
        {
         YssFvgBox("B" + IntegerToString(mid), tLeft, nowT, top, bot, C'40,120,70');
         drawn++;
        }
      else if(YssAnyBearishFvg(_Symbol, PERIOD_CURRENT, mid, top, bot))
        {
         YssFvgBox("S" + IntegerToString(mid), tLeft, nowT, top, bot, C'140,50,60');
         drawn++;
        }
     }
   return(rates_total);
  }
//+------------------------------------------------------------------+
