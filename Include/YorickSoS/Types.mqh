//+------------------------------------------------------------------+
//| YorickSoS/Types.mqh                                              |
//+------------------------------------------------------------------+
#ifndef YORICKSOS_TYPES_MQH
#define YORICKSOS_TYPES_MQH

#define YSS_MAX_ZONES  8
#define YSS_MAX_USED   64

enum ENUM_YSS_STATE
  {
   YSS_IDLE        = 0,
   YSS_WAIT_RETURN = 1,
   YSS_WAIT_SLOW   = 2,
   YSS_IN_TRADE    = 3
  };

enum ENUM_YSS_APPROACH
  {
   YSS_APP_NA    = 0,
   YSS_APP_SLOW  = 1,
   YSS_APP_SHARP = 2,
   YSS_APP_MID   = 3
  };

ENUM_TIMEFRAMES YssResolveTf(const ENUM_TIMEFRAMES tf)
  {
   if(tf == PERIOD_CURRENT)
      return (ENUM_TIMEFRAMES)Period();
   return tf;
  }

string YssTfText(const ENUM_TIMEFRAMES tf)
  {
   string s = EnumToString(tf);
   if(StringFind(s, "PERIOD_") == 0)
      return StringSubstr(s, 7);
   return s;
  }

struct SYssCfg
  {
   string          symbol;
   ENUM_TIMEFRAMES tf;
   double          riskPct;
   ulong           magic;
   ulong           deviation;
   int             maxSpreadPoints;
   int             atrPeriod;
   double          impulseAtrMult;
   double          bodyAtrMult;
   int             swingStrength;
   int             lookback;
   int             maxImpulseBars;
   bool            requireBos;
   bool            requireFvg;
   bool            requireSlow;
   double          slowMaxAtr;
   double          sharpAtr;
   int             minApproachBars;
   double          slZoneMult;
  };

struct SYssZone
  {
   bool     valid;
   int      dir;
   datetime baseTime;
   datetime peakTime;
   datetime bosTime;
   double   zoneHigh;
   double   zoneLow;
   double   impulseExtreme;
   double   entry;
   double   sl;
   double   tp;
   double   fvgTop;
   double   fvgBot;
   bool     hasBos;
   bool     hasFvg;
   bool     consumed;
   bool     invalidated;
  };

struct SYssView
  {
   ENUM_YSS_STATE    state;
   ENUM_YSS_APPROACH approach;
   string            reason;
   SYssZone          zone;
   int               posDir;
   double            posLots;
   double            posSl;
   double            posTp;
   double            posProfit;
   double            nextLots;
   double            riskMoney;
   double            balance;
   double            equity;
   double            atr;
   double            close;
  };

SYssCfg  g_yss_cfg;
SYssView g_yss_view;
SYssZone g_yss_zones[YSS_MAX_ZONES];
int      g_yss_zoneCount = 0;

datetime g_yss_used[YSS_MAX_USED];
int      g_yss_usedCount = 0;

int      g_hAtr = INVALID_HANDLE;
int      g_hStruct = INVALID_HANDLE;
int      g_hFvg = INVALID_HANDLE;
int      g_hZones = INVALID_HANDLE;
datetime g_yss_lastBar = 0;

bool YssShowUi(void)
  {
   return (!MQLInfoInteger(MQL_TESTER) || MQLInfoInteger(MQL_VISUAL_MODE));
  }

string YssStateText(const ENUM_YSS_STATE st)
  {
   if(st == YSS_WAIT_RETURN)
      return "WAIT_RETURN";
   if(st == YSS_WAIT_SLOW)
      return "WAIT_SLOW";
   if(st == YSS_IN_TRADE)
      return "IN_TRADE";
   return "IDLE";
  }

string YssApproachText(const ENUM_YSS_APPROACH a)
  {
   if(a == YSS_APP_SLOW)
      return "slow";
   if(a == YSS_APP_SHARP)
      return "sharp";
   if(a == YSS_APP_MID)
      return "mid";
   return "n/a";
  }

string YssDirText(const int dir)
  {
   if(dir > 0)
      return "DEMAND";
   if(dir < 0)
      return "SUPPLY";
   return "NONE";
  }

void YssZoneClear(SYssZone &z)
  {
   ZeroMemory(z);
   z.valid = false;
   z.dir = 0;
  }

bool YssUsedContains(const datetime t)
  {
   if(t == 0)
      return false;
   for(int i = 0; i < g_yss_usedCount; i++)
     {
      if(g_yss_used[i] == t)
         return true;
     }
   return false;
  }

void YssUsedAdd(const datetime t)
  {
   if(t == 0 || YssUsedContains(t))
      return;
   if(g_yss_usedCount >= YSS_MAX_USED)
     {
      for(int i = 1; i < YSS_MAX_USED; i++)
         g_yss_used[i - 1] = g_yss_used[i];
      g_yss_usedCount = YSS_MAX_USED - 1;
     }
   g_yss_used[g_yss_usedCount++] = t;
  }

#endif
//+------------------------------------------------------------------+
