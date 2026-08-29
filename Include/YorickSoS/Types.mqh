//+------------------------------------------------------------------+
//| YorickSoS/Types.mqh                                              |
//+------------------------------------------------------------------+
#ifndef YORICKSOS_TYPES_MQH
#define YORICKSOS_TYPES_MQH

#define YSS_MAX_ZONES     8
#define YSS_MAX_USED      64
#define YSS_MAX_ZONE_TFS  4

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
   ENUM_TIMEFRAMES trendTf;
   ENUM_TIMEFRAMES zoneTfs[YSS_MAX_ZONE_TFS];
   int             zoneTfCount;
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
   bool            useGuard;
   double          beTriggerR;
   double          trailStartR;
   double          trailDistR;
   bool            requireTrend;
   bool            trendOnZoneTf;     // true=HH/HL on entry zone TF; false=use trendTf
   bool            requireMinRr;
   double          minRiskReward;
   bool            simCommission;     // Strategy Tester only
   double          commissionPerLot;  // USD per lot per side (open or close)
   bool            onePosPerTf;       // true=1 pos per entry TF; false=1 pos global
  };

struct SYssZone
  {
   bool     valid;
   int      dir;
   ENUM_TIMEFRAMES zoneTf;
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
   double            commissionPaid;  // debug: estimated round-trip charged via stops
  };

SYssCfg  g_yss_cfg;
SYssView g_yss_view;
// Independent zone books per entry TF (M5 does not steal slots from M15, etc.)
SYssZone g_yss_zones[YSS_MAX_ZONE_TFS][YSS_MAX_ZONES];
int      g_yss_zoneCount[YSS_MAX_ZONE_TFS];

datetime        g_yss_usedTime[YSS_MAX_USED];
ENUM_TIMEFRAMES g_yss_usedTf[YSS_MAX_USED];
int             g_yss_usedCount = 0;

int      g_hAtr = INVALID_HANDLE;
int      g_hAtrZone[YSS_MAX_ZONE_TFS];
datetime g_yss_lastBarZone[YSS_MAX_ZONE_TFS];
int      g_hStruct = INVALID_HANDLE;
int      g_hFvg = INVALID_HANDLE;
int      g_hZones = INVALID_HANDLE;
datetime g_yss_lastBar = 0;
bool     g_yss_needScan = true;
double   g_yss_atrNow = 0.0;
double   g_yss_atrBuf[];
ulong    g_yss_posTicket = 0;
bool     g_yss_inTrade = false;
int      g_yss_openCount = 0;

struct SYssGuardState
  {
   ulong  ticket;
   double r;
   double best;
   bool   beDone;
  };
SYssGuardState g_yss_guards[YSS_MAX_ZONE_TFS];

void YssGuardsResetAll(void)
  {
   for(int i = 0; i < YSS_MAX_ZONE_TFS; i++)
     {
      g_yss_guards[i].ticket = 0;
      g_yss_guards[i].r = 0.0;
      g_yss_guards[i].best = 0.0;
      g_yss_guards[i].beDone = false;
     }
  }

int YssGuardSlotForTicket(const ulong ticket)
  {
   if(ticket == 0)
      return -1;
   for(int i = 0; i < YSS_MAX_ZONE_TFS; i++)
     {
      if(g_yss_guards[i].ticket == ticket)
         return i;
     }
   for(int i = 0; i < YSS_MAX_ZONE_TFS; i++)
     {
      if(g_yss_guards[i].ticket == 0)
         return i;
     }
   return 0;
  }
bool     g_yss_uiReady = false;
int      g_yss_uiPhase = 0;
double   g_yss_commissionPaid = 0.0;

ulong    g_yss_guardTicket = 0;
double   g_yss_guardR      = 0.0;
double   g_yss_guardBest   = 0.0;
bool     g_yss_guardBeDone = false;

void YssGuardReset(void)
  {
   g_yss_guardTicket = 0;
   g_yss_guardR = 0.0;
   g_yss_guardBest = 0.0;
   g_yss_guardBeDone = false;
   YssGuardsResetAll();
  }

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

bool YssUsedContains(const datetime t, const ENUM_TIMEFRAMES tf)
  {
   if(t == 0)
      return false;
   for(int i = 0; i < g_yss_usedCount; i++)
     {
      if(g_yss_usedTime[i] == t && g_yss_usedTf[i] == tf)
         return true;
     }
   return false;
  }

void YssUsedAdd(const datetime t, const ENUM_TIMEFRAMES tf)
  {
   if(t == 0 || YssUsedContains(t, tf))
      return;
   if(g_yss_usedCount >= YSS_MAX_USED)
     {
      for(int i = 1; i < YSS_MAX_USED; i++)
        {
         g_yss_usedTime[i - 1] = g_yss_usedTime[i];
         g_yss_usedTf[i - 1] = g_yss_usedTf[i];
        }
      g_yss_usedCount = YSS_MAX_USED - 1;
     }
   g_yss_usedTime[g_yss_usedCount] = t;
   g_yss_usedTf[g_yss_usedCount] = tf;
   g_yss_usedCount++;
  }

void YssZonesResetAll(void)
  {
   for(int i = 0; i < YSS_MAX_ZONE_TFS; i++)
      g_yss_zoneCount[i] = 0;
   g_yss_usedCount = 0;
  }

int YssZoneTotalCount(void)
  {
   int n = 0;
   for(int i = 0; i < g_yss_cfg.zoneTfCount; i++)
      n += g_yss_zoneCount[i];
   return n;
  }

int YssZoneTfIndex(const ENUM_TIMEFRAMES tf)
  {
   for(int i = 0; i < g_yss_cfg.zoneTfCount; i++)
     {
      if(g_yss_cfg.zoneTfs[i] == tf)
         return i;
     }
   return -1;
  }

int YssAtrHandleForTf(const ENUM_TIMEFRAMES tf)
  {
   const int idx = YssZoneTfIndex(tf);
   if(idx < 0)
      return INVALID_HANDLE;
   return g_hAtrZone[idx];
  }

string YssZoneTfsText(void)
  {
   string s = "";
   for(int i = 0; i < g_yss_cfg.zoneTfCount; i++)
     {
      if(i > 0)
         s += "+";
      s += YssTfText(g_yss_cfg.zoneTfs[i]);
     }
   return s;
  }

void YssReleaseZoneAtr(void)
  {
   for(int i = 0; i < YSS_MAX_ZONE_TFS; i++)
     {
      if(g_hAtrZone[i] != INVALID_HANDLE)
         IndicatorRelease(g_hAtrZone[i]);
      g_hAtrZone[i] = INVALID_HANDLE;
      g_yss_lastBarZone[i] = 0;
     }
   g_hAtr = INVALID_HANDLE;
   g_yss_cfg.zoneTfCount = 0;
  }

bool YssTfFromText(const string raw, ENUM_TIMEFRAMES &tf)
  {
   string s = raw;
   StringTrimLeft(s);
   StringTrimRight(s);
   StringToUpper(s);
   if(s == "" || s == "NONE" || s == "OFF")
      return false;
   if(s == "CURRENT")
     {
      tf = PERIOD_CURRENT;
      return true;
     }
   if(s == "M1")   { tf = PERIOD_M1;   return true; }
   if(s == "M2")   { tf = PERIOD_M2;   return true; }
   if(s == "M3")   { tf = PERIOD_M3;   return true; }
   if(s == "M4")   { tf = PERIOD_M4;   return true; }
   if(s == "M5")   { tf = PERIOD_M5;   return true; }
   if(s == "M6")   { tf = PERIOD_M6;   return true; }
   if(s == "M10")  { tf = PERIOD_M10;  return true; }
   if(s == "M12")  { tf = PERIOD_M12;  return true; }
   if(s == "M15")  { tf = PERIOD_M15;  return true; }
   if(s == "M20")  { tf = PERIOD_M20;  return true; }
   if(s == "M30")  { tf = PERIOD_M30;  return true; }
   if(s == "H1")   { tf = PERIOD_H1;   return true; }
   if(s == "H2")   { tf = PERIOD_H2;   return true; }
   if(s == "H3")   { tf = PERIOD_H3;   return true; }
   if(s == "H4")   { tf = PERIOD_H4;   return true; }
   if(s == "H6")   { tf = PERIOD_H6;   return true; }
   if(s == "H8")   { tf = PERIOD_H8;   return true; }
   if(s == "H12")  { tf = PERIOD_H12;  return true; }
   if(s == "D1")   { tf = PERIOD_D1;   return true; }
   if(s == "W1")   { tf = PERIOD_W1;   return true; }
   if(s == "MN1")  { tf = PERIOD_MN1;  return true; }
   return false;
  }

bool YssInitZoneTfsFromString(const string csv, const int atrPeriod)
  {
   string parts[];
   int n = StringSplit(csv, ',', parts);
   if(n <= 0)
      n = StringSplit(csv, ';', parts);
   ENUM_TIMEFRAMES list[YSS_MAX_ZONE_TFS];
   int count = 0;
   for(int i = 0; i < n && count < YSS_MAX_ZONE_TFS; i++)
     {
      ENUM_TIMEFRAMES tf;
      if(YssTfFromText(parts[i], tf))
        {
         list[count] = tf;
         count++;
        }
     }
   if(count <= 0)
      return false;
   ENUM_TIMEFRAMES inputs[];
   ArrayResize(inputs, count);
   for(int i = 0; i < count; i++)
      inputs[i] = list[i];
   return YssInitZoneTfs(inputs, atrPeriod);
  }

bool YssInitZoneTfs(const ENUM_TIMEFRAMES &inputs[], const int atrPeriod)
  {
   YssReleaseZoneAtr();

   ENUM_TIMEFRAMES pending[YSS_MAX_ZONE_TFS];
   int pendingCount = 0;
   const int n = ArraySize(inputs);
   for(int i = 0; i < n && pendingCount < YSS_MAX_ZONE_TFS; i++)
     {
      const ENUM_TIMEFRAMES tf = YssResolveTf(inputs[i]);
      if(tf <= 0)
         continue;
      bool dup = false;
      for(int j = 0; j < pendingCount; j++)
        {
         if(pending[j] == tf)
           {
            dup = true;
            break;
           }
        }
      if(!dup)
         pending[pendingCount++] = tf;
     }
   if(pendingCount <= 0)
      return false;

   int finestIdx = 0;
   int finestSec = PeriodSeconds(pending[0]);
   for(int i = 0; i < pendingCount; i++)
     {
      const ENUM_TIMEFRAMES tf = pending[i];
      const int h = iATR(g_yss_cfg.symbol, tf, atrPeriod);
      if(h == INVALID_HANDLE)
         return false;
      g_yss_cfg.zoneTfs[i] = tf;
      g_hAtrZone[i] = h;
      g_yss_lastBarZone[i] = 0;
      const int sec = PeriodSeconds(tf);
      if(sec < finestSec)
        {
         finestSec = sec;
         finestIdx = i;
        }
     }
   g_yss_cfg.zoneTfCount = pendingCount;
   g_hAtr = g_hAtrZone[finestIdx];
   return true;
  }

#endif
//+------------------------------------------------------------------+
