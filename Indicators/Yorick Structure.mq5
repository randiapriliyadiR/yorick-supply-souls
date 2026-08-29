//+------------------------------------------------------------------+
//|                                           Yorick Structure.mq5   |
//|                                                 Randi Apriliyadi |
//|        https://github.com/randiapriliyadiR/yorick-supply-souls |
//+------------------------------------------------------------------+
#property copyright "Randi Apriliyadi"
#property link      "https://github.com/randiapriliyadiR/yorick-supply-souls"
#property version   "1.11"
#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_label1  "Yorick Structure"
#property indicator_type1   DRAW_NONE

#include <YorickSoS/Swings.mqh>

input int  InpSwingStrength = 3;     // Fractal bars each side
input int  InpLookback      = 200;   // Bars to map
input int  InpMaxBos        = 3;     // Max BOS marks (newest first)
input bool InpShowSwingDots = false; // Swing dots (off = cleaner chart)

double g_dummy[];
int    g_stLastBos = 0;
#define YSS_ST_PFX "YSS_ST_"

void YssStClear(void)
  {
   ObjectsDeleteAll(0, YSS_ST_PFX);
  }

void YssStDot(const string key,
              const datetime t,
              const double price,
              const color clr,
              const int arrow)
  {
   const string n = YSS_ST_PFX + key;
   if(ObjectFind(0, n) < 0)
     {
      ObjectCreate(0, n, OBJ_ARROW, 0, t, price);
      ObjectSetInteger(0, n, OBJPROP_ARROWCODE, arrow);
      ObjectSetInteger(0, n, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, n, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, n, OBJPROP_BACK, true);
     }
   ObjectSetInteger(0, n, OBJPROP_TIME, t);
   ObjectSetDouble(0, n, OBJPROP_PRICE, price);
   ObjectSetInteger(0, n, OBJPROP_COLOR, clr);
  }

void YssStBos(const string key,
              const datetime t1,
              const double p1,
              const datetime t2,
              const double p2,
              const color clr,
              const bool labeled)
  {
   const string n = YSS_ST_PFX + key;
   if(ObjectFind(0, n) < 0)
     {
      ObjectCreate(0, n, OBJ_TREND, 0, t1, p1, t2, p2);
      ObjectSetInteger(0, n, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, n, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, n, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, n, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, n, OBJPROP_BACK, true);
     }
   ObjectSetInteger(0, n, OBJPROP_TIME, t1);
   ObjectSetDouble(0, n, OBJPROP_PRICE, p1);
   ObjectSetInteger(0, n, OBJPROP_TIME, 1, t2);
   ObjectSetDouble(0, n, OBJPROP_PRICE, 1, p2);
   ObjectSetInteger(0, n, OBJPROP_COLOR, clr);

   const string lb = n + "_L";
   if(!labeled)
     {
      ObjectDelete(0, lb);
      return;
     }
   if(ObjectFind(0, lb) < 0)
     {
      ObjectCreate(0, lb, OBJ_TEXT, 0, t2, p2);
      ObjectSetInteger(0, lb, OBJPROP_FONTSIZE, 8);
      ObjectSetString(0, lb, OBJPROP_FONT, "Consolas");
      ObjectSetInteger(0, lb, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, lb, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, lb, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
     }
   ObjectSetInteger(0, lb, OBJPROP_TIME, t2);
   ObjectSetDouble(0, lb, OBJPROP_PRICE, p2);
   ObjectSetInteger(0, lb, OBJPROP_COLOR, clr);
   ObjectSetString(0, lb, OBJPROP_TEXT, " BOS");
  }

int OnInit()
  {
   if(InpSwingStrength < 1 || InpLookback < 20 || InpMaxBos < 1)
      return(INIT_PARAMETERS_INCORRECT);
   SetIndexBuffer(0, g_dummy, INDICATOR_CALCULATIONS);
   IndicatorSetString(INDICATOR_SHORTNAME, "Yorick Structure");
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   YssStClear();
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
   if(!YssSeriesLoad(_Symbol, (ENUM_TIMEFRAMES)Period(), InpLookback + 8))
      return(prev_calculated);

   const int strength = InpSwingStrength;
   const int last = MathMin(InpLookback, rates_total - strength - 2);
   const int maxBos = MathMin(InpMaxBos, 8);
   int bosN = 0;

   for(int s = strength + 1; s <= last && bosN < maxBos; s++)
     {
      if(YssIsSwingHigh(_Symbol, (ENUM_TIMEFRAMES)Period(), s, strength))
        {
         const datetime t = YssT(_Symbol, PERIOD_CURRENT, s);
         const double p = YssH(_Symbol, PERIOD_CURRENT, s);
         if(InpShowSwingDots)
            YssStDot("SH" + IntegerToString(s), t, p, clrDodgerBlue, 159);
         datetime bosTime = 0;
         if(YssBosDemand(_Symbol, PERIOD_CURRENT, s - 1, 1, p, bosTime))
           {
            YssStBos("BH" + IntegerToString(bosN), t, p, bosTime, p,
                     C'70,150,220', bosN == 0);
            ObjectDelete(0, YSS_ST_PFX + "BL" + IntegerToString(bosN));
            ObjectDelete(0, YSS_ST_PFX + "BL" + IntegerToString(bosN) + "_L");
            bosN++;
           }
        }
      if(bosN >= maxBos)
         break;
      if(YssIsSwingLow(_Symbol, (ENUM_TIMEFRAMES)Period(), s, strength))
        {
         const datetime t = YssT(_Symbol, PERIOD_CURRENT, s);
         const double p = YssL(_Symbol, PERIOD_CURRENT, s);
         if(InpShowSwingDots)
            YssStDot("SL" + IntegerToString(s), t, p, clrOrchid, 159);
         datetime bosTime = 0;
         if(YssBosSupply(_Symbol, PERIOD_CURRENT, s - 1, 1, p, bosTime))
           {
            YssStBos("BL" + IntegerToString(bosN), t, p, bosTime, p,
                     C'190,120,210', bosN == 0);
            ObjectDelete(0, YSS_ST_PFX + "BH" + IntegerToString(bosN));
            ObjectDelete(0, YSS_ST_PFX + "BH" + IntegerToString(bosN) + "_L");
            bosN++;
           }
        }
     }
   for(int i = bosN; i < g_stLastBos; i++)
     {
      ObjectDelete(0, YSS_ST_PFX + "BH" + IntegerToString(i));
      ObjectDelete(0, YSS_ST_PFX + "BH" + IntegerToString(i) + "_L");
      ObjectDelete(0, YSS_ST_PFX + "BL" + IntegerToString(i));
      ObjectDelete(0, YSS_ST_PFX + "BL" + IntegerToString(i) + "_L");
     }
   g_stLastBos = bosN;
   return(rates_total);
  }
//+------------------------------------------------------------------+
