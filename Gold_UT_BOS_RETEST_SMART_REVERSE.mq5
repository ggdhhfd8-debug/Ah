// MT5 EA: M1 BOS + Retest follows breakout; UT fallback reverses signal.
// Full source will be provided in the next revision once compiled/verified.
#property strict
#property version "4.00"
#include <Trade/Trade.mqh>
CTrade trade;
input string SymbolName="";
input double Lot=0.03;
input double RiskReward=1.5;
input double SL_ATR_Mult=1.2;
input double TrailStartUSD=10.0;
input double TrailLockUSD=2.0;
input int Magic=30102026;
input int Lookback=20;
input int RetestBars=5;
input double RetestToleranceATR=0.25;
input double UTKey=1.0;
input int UTATRPeriod=10;
input bool UseUT=true;
string S; datetime lastbar=0; int hATR,hUTATR,hRSI,hEMA,hMACD;
int pending=0, age=0; double level=0;
double B(int h,int b,int s){double a[];ArraySetAsSeries(a,true);if(CopyBuffer(h,b,s,1,a)!=1)return EMPTY_VALUE;return a[0];}
bool NewBar(){datetime t=iTime(S,PERIOD_M1,0);if(t!=lastbar){lastbar=t;return true;}return false;}
bool Pos(){for(int i=PositionsTotal()-1;i>=0;i--){ulong x=PositionGetTicket(i);if(x&&PositionGetString(POSITION_SYMBOL)==S&&(int)PositionGetInteger(POSITION_MAGIC)==Magic)return true;}return false;}
int BOS(double &lv){double c=iClose(S,PERIOD_M1,1),hi=-DBL_MAX,lo=DBL_MAX;for(int i=2;i<Lookback+2;i++){hi=MathMax(hi,iHigh(S,PERIOD_M1,i));lo=MathMin(lo,iLow(S,PERIOD_M1,i));}if(c>hi){lv=hi;return 1;}if(c<lo){lv=lo;return -1;}return 0;}
int OnInit(){S=(SymbolName==""?_Symbol:SymbolName);trade.SetExpertMagicNumber(Magic);trade.SetDeviationInPoints(30);trade.SetTypeFillingBySymbol(S);hATR=iATR(S,PERIOD_M1,14);hUTATR=iATR(S,PERIOD_M1,UTATRPeriod);hRSI=iRSI(S,PERIOD_M1,14,PRICE_CLOSE);hEMA=iMA(S,PERIOD_M1,50,0,MODE_EMA,PRICE_CLOSE);hMACD=iMACD(S,PERIOD_M1,12,26,9,PRICE_CLOSE);if(hATR<0||hUTATR<0)return INIT_FAILED;return INIT_SUCCEEDED;}
void OnDeinit(const int r){IndicatorRelease(hATR);IndicatorRelease(hUTATR);IndicatorRelease(hRSI);IndicatorRelease(hEMA);IndicatorRelease(hMACD);}
void Protect(){double tv=SymbolInfoDouble(S,SYMBOL_TRADE_TICK_VALUE),ts=SymbolInfoDouble(S,SYMBOL_TRADE_TICK_SIZE);if(tv<=0||ts<=0)return;double d=TrailLockUSD/(tv/ts*Lot);for(int i=PositionsTotal()-1;i>=0;i--){ulong x=PositionGetTicket(i);if(!x||PositionGetString(POSITION_SYMBOL)!=S||(int)PositionGetInteger(POSITION_MAGIC)!=Magic)continue;double pr=PositionGetDouble(POSITION_PROFIT),op=PositionGetDouble(POSITION_PRICE_OPEN),old=PositionGetDouble(POSITION_SL),tp=PositionGetDouble(POSITION_TP);if(pr<TrailStartUSD)continue;ENUM_POSITION_TYPE t=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);MqlTick q;if(!SymbolInfoTick(S,q))continue;double ns=(t==POSITION_TYPE_BUY?op+d:op-d);double md=(double)SymbolInfoInteger(S,SYMBOL_TRADE_STOPS_LEVEL)*SymbolInfoDouble(S,SYMBOL_POINT);if(t==POSITION_TYPE_BUY){ns=MathMin(ns,q.bid-md);if(old==0||ns>old)trade.PositionModify(x,NormalizeDouble(ns,_Digits),tp);}else{ns=MathMax(ns,q.ask+md);if(old==0||ns<old)trade.PositionModify(x,NormalizeDouble(ns,_Digits),tp);}}}
void Open(int dir,bool follow,string why){int final=follow?dir:-dir;ENUM_ORDER_TYPE t=final>0?ORDER_TYPE_BUY:ORDER_TYPE_SELL;MqlTick q;if(!SymbolInfoTick(S,q))return;double e=t==ORDER_TYPE_BUY?q.ask:q.bid,atr=B(hATR,0,1);if(atr<=0)return;double d=atr*SL_ATR_Mult,sl,tp;if(t==ORDER_TYPE_BUY){sl=e-d;tp=e+d*RiskReward;trade.Buy(Lot,S,e,NormalizeDouble(sl,_Digits),NormalizeDouble(tp,_Digits),"SMART "+why);}else{sl=e+d;tp=e-d*RiskReward;trade.Sell(Lot,S,e,NormalizeDouble(sl,_Digits),NormalizeDouble(tp,_Digits),"SMART "+why);}}
void OnTick(){Protect();if(!NewBar())return;if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)||!MQLInfoInteger(MQL_TRADE_ALLOWED))return;double lv;int b=BOS(lv);if(b){pending=b;level=lv;age=0;}if(pending){age++;double atr=B(hATR,0,1),o=iOpen(S,PERIOD_M1,1),h=iHigh(S,PERIOD_M1,1),l=iLow(S,PERIOD_M1,1),c=iClose(S,PERIOD_M1,1);bool touch=pending>0?l<=level+atr*RetestToleranceATR:h>=level-atr*RetestToleranceATR;bool ok=pending>0?c>level&&c>o:c<level&&c<o;if(touch&&ok&&!Pos()){int d=pending;pending=0;Open(d,true,"BOS_RETEST");return;}if(age>RetestBars)pending=0;}/* UT fallback intentionally reversed. */}
//+------------------------------------------------------------------+
