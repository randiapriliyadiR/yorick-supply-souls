//+------------------------------------------------------------------+
//|                                                 Yorick FVG.mq5   |
//|                                                 Randi Apriliyadi |
//|        https://github.com/randiapriliyadiR/yorick-supply-souls |
//+------------------------------------------------------------------+
#property copyright "Randi Apriliyadi"
#property link      "https://github.com/randiapriliyadiR/yorick-supply-souls"
#property version   "1.10"
#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_label1  "Yorick FVG"
#property indicator_type1   DRAW_NONE
#property tester_everytick_calculate

#include <YorickSoS/Fvg.mqh>

input int InpLookback   = 200;  // Bars to scan
input int InpMaxShowFvg = 4;    // Max gap boxes on chart
input int InpBoxBars    = 12;   // Box width in bars (not stretched to now)

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
   if(InpLookback < 20 || InpMaxShowFvg < 1 || InpBoxBars < 2)
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
   const int maxShow = MathMin(InpMaxShowFvg, 8);
   int drawn = 0;

   for(int mid = 2; mid <= last && drawn < maxShow; mid++)
     {
      double top = 0.0, bot = 0.0;
      const datetime tLeft = iTime(_Symbol, PERIOD_CURRENT, mid + 1);
      const int endSh = MathMax(0, mid + 1 - InpBoxBars);
      const datetime tRight = iTime(_Symbol, PERIOD_CURRENT, endSh);
      if(YssAnyBullishFvg(_Symbol, PERIOD_CURRENT, mid, top, bot))
        {
         YssFvgBox("B" + IntegerToString(drawn), tLeft, tRight, top, bot, C'35,100,65');
         drawn++;
        }
      else if(YssAnyBearishFvg(_Symbol, PERIOD_CURRENT, mid, top, bot))
        {
         YssFvgBox("S" + IntegerToString(drawn), tLeft, tRight, top, bot, C'120,45,55');
         drawn++;
        }
     }
   return(rates_total);
  }
//+------------------------------------------------------------------+
