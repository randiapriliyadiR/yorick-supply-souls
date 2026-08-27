//+------------------------------------------------------------------+
//|                                               Yorick Zones.mq5   |
//|                                                 Randi Apriliyadi |
//|                              https://github.com/randiapriliyadiR |
//+------------------------------------------------------------------+
#property copyright "Randi Apriliyadi"
#property link      "https://github.com/randiapriliyadiR"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_label1  "Yorick Zones"
#property indicator_type1   DRAW_NONE
#property tester_everytick_calculate

#include <YorickSoS/Types.mqh>
#include <YorickSoS/Zones.mqh>

input int    InpAtrPeriod      = 14;
input double InpImpulseAtrMult = 1.25;
input double InpBodyAtrMult    = 0.65;
input int    InpSwingStrength  = 3;
input int    InpLookback       = 200;
input int    InpMaxImpulseBars = 15;
input bool   InpRequireBos     = true;
input bool   InpRequireFvg     = true;
input double InpSlZoneMult     = 2.5;

double g_dummy[];
int    g_indAtr = INVALID_HANDLE;
#define YSS_ZN_PFX "YSS_ZN_"

void YssZnClear(void)
  {
   ObjectsDeleteAll(0, YSS_ZN_PFX);
  }

void YssZnBox(const string key,
              const datetime t1,
              const datetime t2,
              const double top,
              const double bot,
              const color clr,
              const bool fill)
  {
   const string n = YSS_ZN_PFX + key;
   if(ObjectFind(0, n) < 0)
     {
      ObjectCreate(0, n, OBJ_RECTANGLE, 0, t1, top, t2, bot);
      ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, n, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, n, OBJPROP_BACK, true);
      ObjectSetInteger(0, n, OBJPROP_WIDTH, 1);
     }
   ObjectSetInteger(0, n, OBJPROP_TIME, t1);
   ObjectSetDouble(0, n, OBJPROP_PRICE, top);
   ObjectSetInteger(0, n, OBJPROP_TIME, 1, t2);
   ObjectSetDouble(0, n, OBJPROP_PRICE, 1, bot);
   ObjectSetInteger(0, n, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, n, OBJPROP_BGCOLOR, clr);
   ObjectSetInteger(0, n, OBJPROP_FILL, fill);
  }

void YssZnLine(const string key,
               const datetime t1,
               const datetime t2,
               const double price,
               const color clr)
  {
   const string n = YSS_ZN_PFX + key;
   if(ObjectFind(0, n) < 0)
     {
      ObjectCreate(0, n, OBJ_TREND, 0, t1, price, t2, price);
      ObjectSetInteger(0, n, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, n, OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(0, n, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, n, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, n, OBJPROP_BACK, true);
     }
   ObjectSetInteger(0, n, OBJPROP_TIME, t1);
   ObjectSetDouble(0, n, OBJPROP_PRICE, price);
   ObjectSetInteger(0, n, OBJPROP_TIME, 1, t2);
   ObjectSetDouble(0, n, OBJPROP_PRICE, 1, price);
   ObjectSetInteger(0, n, OBJPROP_COLOR, clr);
  }

int OnInit()
  {
   if(InpAtrPeriod < 1 || InpLookback < 30 || InpSlZoneMult < 1.0)
      return(INIT_PARAMETERS_INCORRECT);
   SetIndexBuffer(0, g_dummy, INDICATOR_CALCULATIONS);
   IndicatorSetString(INDICATOR_SHORTNAME, "Yorick Zones");
   g_indAtr = iATR(_Symbol, PERIOD_CURRENT, InpAtrPeriod);
   if(g_indAtr == INVALID_HANDLE)
      return(INIT_FAILED);
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   YssZnClear();
   if(g_indAtr != INVALID_HANDLE)
      IndicatorRelease(g_indAtr);
   g_indAtr = INVALID_HANDLE;
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
   if(rates_total < InpLookback || g_indAtr == INVALID_HANDLE)
      return(0);
   if(prev_calculated == rates_total)
      return(rates_total);
   if(BarsCalculated(g_indAtr) < InpAtrPeriod + 2)
      return(prev_calculated);

   double atr[];
   ArraySetAsSeries(atr, true);
   if(CopyBuffer(g_indAtr, 0, 0, InpLookback + 2, atr) < InpLookback)
      return(prev_calculated);

   SYssCfg cfg;
   ZeroMemory(cfg);
   cfg.symbol = _Symbol;
   cfg.tf = (ENUM_TIMEFRAMES)Period();
   cfg.atrPeriod = InpAtrPeriod;
   cfg.impulseAtrMult = InpImpulseAtrMult;
   cfg.bodyAtrMult = InpBodyAtrMult;
   cfg.swingStrength = InpSwingStrength;
   cfg.lookback = InpLookback;
   cfg.maxImpulseBars = InpMaxImpulseBars;
   cfg.requireBos = InpRequireBos;
   cfg.requireFvg = InpRequireFvg;
   cfg.slZoneMult = InpSlZoneMult;

   YssZnClear();
   const datetime nowT = iTime(_Symbol, PERIOD_CURRENT, 0);
   int drawn = 0;
   const int last = InpLookback - cfg.swingStrength - 1;

   for(int b = 3; b <= last && drawn < 12; b++)
     {
      const double a = atr[b];
      if(a <= 0.0)
         continue;
      SYssZone z;
      bool ok = YssBuildZoneAt(cfg, b, 1, a, z, false);
      if(!ok)
         ok = YssBuildZoneAt(cfg, b, -1, a, z, false);
      if(!ok)
         continue;

      const datetime t1 = z.baseTime;
      const color zclr = (z.dir > 0 ? C'40,140,90' : C'160,55,70');
      const color bclr = (z.dir > 0 ? C'30,80,55' : C'90,35,45');
      YssZnBox("Z" + IntegerToString(b), t1, nowT, z.zoneHigh, z.zoneLow, zclr, true);
      if(z.dir > 0)
         YssZnBox("B" + IntegerToString(b), t1, nowT, z.zoneLow, z.sl, bclr, false);
      else
         YssZnBox("B" + IntegerToString(b), t1, nowT, z.sl, z.zoneHigh, bclr, false);
      YssZnLine("E" + IntegerToString(b), t1, nowT, z.impulseExtreme,
                (z.dir > 0 ? clrDodgerBlue : clrOrchid));
      drawn++;
     }
   return(rates_total);
  }
//+------------------------------------------------------------------+
