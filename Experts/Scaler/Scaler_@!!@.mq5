//+------------------------------------------------------------------+
//|                                            HFT_Bracket_Pro.mq5   |
//|                      High-Frequency Bracket Scalping EA          |
//|                Based on YouTube Logic + Professional Features    |
//+------------------------------------------------------------------+
#property copyright "HFT Bracket Pro - Professional Edition"
#property version   "1.00" 
#property strict



#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>

//--- Global Objects
CTrade trade;
CPositionInfo positionInfo;
COrderInfo orderInfo;

//+------------------------------------------------------------------+
//| Input Parameters                                                 |
//+------------------------------------------------------------------+

input group "=== EA IDENTIFICATION ==="
input string InpEAName = "HFT_Bracket";        // EA Name
input int    InpMagic = 200001;                // Magic Number

input group "=== POSITION SIZING ==="
enum ENUM_RISK_MODE
{
   RISK_FIXED_LOTS,    // Fixed Lot Size
   RISK_PERCENT,       // Risk % of Equity
   RISK_DOLLAR         // Fixed Dollar Risk
};
input ENUM_RISK_MODE InpRiskMode = RISK_PERCENT;  // Risk Mode
input double InpFixedLots = 0.01;                 // Fixed Lot Size
input double InpRiskPercent = 2.0;                // Risk % per trade
input double InpRiskDollar = 100.0;               // Risk $ per trade
input double InpMaxLotSize = 10.0;                // Maximum Lot Size

input group "=== BRACKET ORDER SETTINGS (× Spread) ==="
input double Delta = 0.5;                      // Order Distance (× spread)
input double Theta = 7.0;                      // Max Order Distance (× spread)
input double InitialStop = 10.0;               // Initial Stop Loss (× spread)
input double Kost = 4.0;                       // Profit to Start Trail (× spread)

input group "=== ORDER MODIFICATION ==="
input int    ModificationInterval = 60;        // Modification Interval (seconds)
input double ModificationFactor = 3.0;         // Modification Factor

input group "=== SCALING IN ==="
input bool   EnableScaling = true;             // Enable Scaling In
input int    MaxScalePositions = 3;            // Max Scale-In Positions

input group "=== DAILY LOSS PROTECTION ==="
input bool   UseDailyLossLimit = true;         // Use Daily Loss Limit
input double DailyLossPercent = 5.0;           // Daily Loss % Limit

input group "=== SESSION MANAGEMENT ==="
input bool   shouldUseSessionManagement = false; // Use Session Management
input int    SessionStartHour = 07;            // Session Start Hour
input int    SessionEndHour = 10;              // Session End Hour (1 hour max!)
input int    MaxTradesPerSession = 200;        // Max Trades Warning

input group "=== VWAP FILTER (Optional) ==="
input bool   UseVWAPFilter = false;            // Use VWAP Filter
input int    VWAP_Period = 20;                 // VWAP Period

input group "=== ATR FILTER (Optional) ==="
input bool   UseATRFilter = false;             // Use ATR Filter
input int    ATR_Period = 14;                  // ATR Period
input double ATR_MinPercent = 0.03;            // Min ATR (% of price)

input group "=== ADX FILTER (Optional) ==="
input bool   UseADXFilter = false;             // Use ADX Filter
input int    ADX_Period = 14;                  // ADX Period
input double ADX_MinLevel = 20.0;              // Min ADX Level

input group "=== SPREAD FILTER ==="
input double MaxSpreadPercent = 0.03;          // Max Spread (% of price)

//--- Global Variables
// Symbol parameters
double SymPoint;
int    SymDigits;
double MinStopDistance;
double MinFreezeDistance;

// Broker limits
double BrokerMinLot;
double BrokerMaxLot;
double BrokerLotStep;

// Spread tracking
double CurrentSpread;
double AverageSpread;
double SpreadArray[];
int    SpreadArraySize = 30;

// Order tracking
ulong  BuyOrderTicket = 0;
ulong  SellOrderTicket = 0;
datetime LastBuyOrderTime = 0;
datetime LastSellOrderTime = 0;
datetime LastModificationTime = 0;

// Position tracking
double LowestBuyPrice = 0;
double HighestSellPrice = 0;
double CurrentBuyStopLoss = 0;
double CurrentSellStopLoss = 0;
int    OpenBuyCount = 0;
int    OpenSellCount = 0;
int    TotalBuyCount = 0;
int    TotalSellCount = 0;

// Trailing
double BaseTrailingStop;
double TrailingStopIncrement;

// Daily session tracking
double   SessionStartBalance = 0.0;
datetime CurrentSessionDay = 0;
bool     DailyLimitReached = false;
int      SessionTradeCount = 0;

// Indicator handles
int      VWAPHandle = INVALID_HANDLE;
int      ATRHandle = INVALID_HANDLE;
int      ADXHandle = INVALID_HANDLE;

// Internal filter flags (can be modified at runtime) - FIXED!
bool     VWAPFilterActive = false;
bool     ATRFilterActive = false;
bool     ADXFilterActive = false;

// Calculated values
double   AdjustedOrderDistance;
double   MaxOrderPlacementDistance;
double   CalculatedStopLoss;
double   TrailingStopActive;
double   TrailingStopMax;

// Commission tracking
double   CommissionPerPip = 0;
double   PriceToPipRatio = 0;

// Status
bool     TradingAllowed = false;
string   StatusMessage = "";

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Set magic number
   trade.SetExpertMagicNumber(InpMagic);
   
   // Remove grid
   ChartSetInteger(0, CHART_SHOW_GRID, false);
   
   // Initialize symbol parameters
   UpdateSymbolParameters();
   
   // Get broker limits
   BrokerMinLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   BrokerMaxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   BrokerLotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   // Initialize spread array
   ArrayResize(SpreadArray, SpreadArraySize);
   ArrayInitialize(SpreadArray, 0);
   
   // Get initial spread
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   CurrentSpread = NormalizeDouble(ask - bid, SymDigits);
   AverageSpread = CurrentSpread;
   
   // Populate spread array
   for(int i = 0; i < SpreadArraySize; i++)
      SpreadArray[i] = CurrentSpread;
   
   // Initialize VWAP - FIXED!
   VWAPFilterActive = UseVWAPFilter;
   if(UseVWAPFilter)
   {
      VWAPHandle = iCustom(_Symbol, PERIOD_CURRENT, "Examples\\VWAP", VWAP_Period);
      if(VWAPHandle == INVALID_HANDLE)
      {
         Print("⚠️ VWAP indicator failed to load - disabling VWAP filter");
         VWAPFilterActive = false;
      }
   }
   
   // Initialize ATR (M1 for scalping!) - FIXED!
   ATRFilterActive = UseATRFilter;
   if(UseATRFilter)
   {
      ATRHandle = iATR(_Symbol, PERIOD_M1, ATR_Period);
      if(ATRHandle == INVALID_HANDLE)
      {
         Print("⚠️ ATR indicator failed - disabling ATR filter");
         ATRFilterActive = false;
      }
   }
   
   // Initialize ADX - FIXED!
   ADXFilterActive = UseADXFilter;
   if(UseADXFilter)
   {
      ADXHandle = iADX(_Symbol, PERIOD_M15, ADX_Period);
      if(ADXHandle == INVALID_HANDLE)
      {
         Print("⚠️ ADX indicator failed - disabling ADX filter");
         ADXFilterActive = false;
      }
   }
   
   // Initialize daily session
   CurrentSessionDay = DayStart(TimeCurrent());
   SessionStartBalance = AccountInfoDouble(ACCOUNT_EQUITY);
   DailyLimitReached = false;
   SessionTradeCount = 0;
   
   // Calculate commission from history
   CalculateCommissionFromHistory();
   
   // Initialize trailing values
   BaseTrailingStop = Kost;
   TrailingStopIncrement = Kost;
   
   // Log initialization
   Print("═══════════════════════════════════════");
   Print("=== HFT BRACKET PRO INITIALIZED ===");
   Print("═══════════════════════════════════════");
   Print("Symbol: ", _Symbol);
   Print("Magic: ", InpMagic);
   Print("Risk Mode: ", EnumToString(InpRiskMode));
   Print("Order Distance: ", Delta, "× spread");
   Print("Initial SL: ", InitialStop, "× spread");
   Print("Trail Start: ", Kost, "× spread");
   Print("Scaling In: ", EnableScaling ? "ON" : "OFF");
   Print("Max Positions: ", MaxScalePositions);
   Print("Daily Limit: ", UseDailyLossLimit ? StringFormat("%.1f%%", DailyLossPercent) : "OFF");
   Print("Session: ", SessionStartHour, ":00 - ", SessionEndHour, ":00");
   Print("VWAP Filter: ", VWAPFilterActive ? "ON" : "OFF");
   Print("ATR Filter: ", ATRFilterActive ? "ON (M1)" : "OFF");
   Print("ADX Filter: ", ADXFilterActive ? "ON" : "OFF");
   Print("═══════════════════════════════════════");
   Print("⚠️ WARNING: HIGH FREQUENCY EA");
   Print("⚠️ Run for 10-15 minutes MAX per session!");
   Print("⚠️ Monitor broker warnings closely!");
   Print("═══════════════════════════════════════");
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Release indicators
   if(VWAPHandle != INVALID_HANDLE) IndicatorRelease(VWAPHandle);
   if(ATRHandle != INVALID_HANDLE) IndicatorRelease(ATRHandle);
   if(ADXHandle != INVALID_HANDLE) IndicatorRelease(ADXHandle);
   
   // Clear chart
   Comment("");
   
   Print("HFT Bracket Pro deinitialized. Reason: ", reason);
   Print("Session trades: ", SessionTradeCount);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Check for new session
   CheckNewSession();
   
   // Check daily loss limit
   if(CheckDailyLossLimit())
   {
      UpdateChartDisplay();
      return;
   }
   
   // Check if trading allowed (time + trade count)
   if(!IsSessionActive())
   {
      TradingAllowed = false;
      StatusMessage = "Outside trading hours";
      UpdateChartDisplay();
      return;
   }
   
   // Update symbol parameters
   UpdateSymbolParameters();
   
   // Update spread
   UpdateSpread();
   
   // Calculate distances
   CalculateDistances();
   
   // Count positions
   CountPositions();
   
   // Check filters
   if(!PassAllFilters())
   {
      UpdateChartDisplay();
      return;
   }
   
   TradingAllowed = true;
   StatusMessage = "Trading ACTIVE";
   
   // Main logic
   ManageOpenPositions();      // Trail existing positions
   ModifyPendingOrders();      // Adjust pending orders
   PlaceBracketOrders();       // Place new bracket orders
   CheckForScaleIn();          // Add positions if scaling enabled
   
   // Update display
   UpdateChartDisplay();
}

//+------------------------------------------------------------------+
//| Update Symbol Parameters                                        |
//+------------------------------------------------------------------+
void UpdateSymbolParameters()
{
   SymPoint = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   SymDigits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   
   // Get broker stop level
   int brokerStopLevel = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   MinStopDistance = (brokerStopLevel > 0) ? (brokerStopLevel + 1) * SymPoint : 0;
   
   // Get broker freeze level
   int brokerFreezeLevel = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   MinFreezeDistance = (brokerFreezeLevel > 0) ? (brokerFreezeLevel + 1) * SymPoint : 0;
}

//+------------------------------------------------------------------+
//| Update Spread Tracking                                          |
//+------------------------------------------------------------------+
void UpdateSpread()
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   CurrentSpread = NormalizeDouble(ask - bid, SymDigits);
   
   // Shift array left and add new spread
   for(int i = SpreadArraySize - 1; i > 0; i--)
      SpreadArray[i] = SpreadArray[i-1];
   
   SpreadArray[0] = CurrentSpread;
   
   // Calculate average
   double sum = 0;
   for(int i = 0; i < SpreadArraySize; i++)
      sum += SpreadArray[i];
   
   AverageSpread = sum / SpreadArraySize;
   
   // Add commission
   AverageSpread = AverageSpread + (CommissionPerPip > 0 ? CommissionPerPip : 0);
}

//+------------------------------------------------------------------+
//| Calculate Distances                                             |
//+------------------------------------------------------------------+
void CalculateDistances()
{
   // Adjusted order distance
   AdjustedOrderDistance = MathMax(AverageSpread * Delta, MinStopDistance + SymPoint);
   
   // Max order placement distance
   MaxOrderPlacementDistance = Theta * AverageSpread;
   
   // Calculated stop loss
   CalculatedStopLoss = MathMax(InitialStop * AverageSpread, MinStopDistance + SymPoint);
   
   // Trailing stop values
   TrailingStopActive = Kost * AverageSpread;
   TrailingStopMax = 7.5 * AverageSpread;
}

//+------------------------------------------------------------------+
//| Count Open Positions and Orders                                 |
//+------------------------------------------------------------------+
void CountPositions()
{
   OpenBuyCount = 0;
   OpenSellCount = 0;
   TotalBuyCount = 0;
   TotalSellCount = 0;
   LowestBuyPrice = 0;
   HighestSellPrice = 0;
   
   // Count positions
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!positionInfo.SelectByIndex(i)) continue;
      if(positionInfo.Magic() != InpMagic) continue;
      if(positionInfo.Symbol() != _Symbol) continue;
      
      double price = positionInfo.PriceOpen();
      double sl = positionInfo.StopLoss();
      
      if(positionInfo.PositionType() == POSITION_TYPE_BUY)
      {
         OpenBuyCount++;
         TotalBuyCount++;
         
         if(LowestBuyPrice == 0 || price < LowestBuyPrice)
            LowestBuyPrice = price;
         
         if(sl > 0 && sl < price)
            CurrentBuyStopLoss = sl;
      }
      else
      {
         OpenSellCount++;
         TotalSellCount++;
         
         if(HighestSellPrice == 0 || price > HighestSellPrice)
            HighestSellPrice = price;
         
         if(sl > 0 && sl > price)
            CurrentSellStopLoss = sl;
      }
   }
   
   // Count pending orders
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!orderInfo.SelectByIndex(i)) continue;
      if(orderInfo.Magic() != InpMagic) continue;
      if(orderInfo.Symbol() != _Symbol) continue;
      
      ENUM_ORDER_TYPE type = orderInfo.OrderType();
      
      if(type == ORDER_TYPE_BUY_STOP)
         TotalBuyCount++;
      else if(type == ORDER_TYPE_SELL_STOP)
         TotalSellCount++;
   }
}

//+------------------------------------------------------------------+
//| Professional Filter Suite                                        |
//+------------------------------------------------------------------+
bool PassAllFilters()
{
   // Spread filter
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double spreadPercent = (CurrentSpread / currentPrice) * 100.0;
   
   if(spreadPercent > MaxSpreadPercent)
   {
      StatusMessage = StringFormat("Spread too wide: %.4f%%", spreadPercent);
      return false;
   }
   
   // VWAP filter - FIXED!
   if(VWAPFilterActive && !CheckVWAPFilter())
   {
      return false;
   }
   
   // ATR filter - FIXED!
   if(ATRFilterActive && !CheckATRFilter())
   {
      return false;
   }
   
   // ADX filter - FIXED!
   if(ADXFilterActive && !CheckADXFilter())
   {
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| VWAP Filter                                                      |
//+------------------------------------------------------------------+
bool CheckVWAPFilter()
{
   if(VWAPHandle == INVALID_HANDLE) return true;
   
   double vwap[];
   if(CopyBuffer(VWAPHandle, 0, 0, 1, vwap) <= 0) return true;
   
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // If price below VWAP, only allow shorts (sell)
   // If price above VWAP, only allow longs (buy)
   
   if(currentPrice < vwap[0] && OpenBuyCount > 0)
   {
      StatusMessage = "VWAP: Below - shorts only";
      return false;
   }
   
   if(currentPrice > vwap[0] && OpenSellCount > 0)
   {
      StatusMessage = "VWAP: Above - longs only";
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| ATR Filter                                                       |
//+------------------------------------------------------------------+
bool CheckATRFilter()
{
   if(ATRHandle == INVALID_HANDLE) return true;
   
   double atr[];
   if(CopyBuffer(ATRHandle, 0, 0, 1, atr) <= 0) return true;
   
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double atrPercent = (atr[0] / currentPrice) * 100.0;
   
   if(atrPercent < ATR_MinPercent)
   {
      StatusMessage = StringFormat("ATR too low: %.4f%%", atrPercent);
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| ADX Filter                                                       |
//+------------------------------------------------------------------+
bool CheckADXFilter()
{
   if(ADXHandle == INVALID_HANDLE) return true;
   
   double adx[];
   if(CopyBuffer(ADXHandle, 0, 0, 1, adx) <= 0) return true;
   
   if(adx[0] < ADX_MinLevel)
   {
      StatusMessage = StringFormat("ADX too low: %.1f", adx[0]);
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Check if Date is in US Daylight Saving Time                      |
//| DST starts: Second Sunday of March at 2:00 AM                    |
//| DST ends: First Sunday of November at 2:00 AM                    |
//+------------------------------------------------------------------+
bool IsNewYorkDST(datetime time)
{
   MqlDateTime dt;
   TimeToStruct(time, dt);
   
   int month = dt.mon;
   int day = dt.day;
   int dow = dt.day_of_week; // 0 = Sunday
   int hour = dt.hour;
   
   // January, February - No DST
   if(month < 3) return false;
   
   // April to October - DST active
   if(month > 3 && month < 11) return true;
   
   // March - DST starts on second Sunday
   if(month == 3)
   {
      // Find second Sunday: it's between day 8-14
      int secondSunday = 8 + (7 - ((dow - day % 7 + 7) % 7 + 8 - 1) % 7);
      // Simplified: calculate which Sunday we're on
      int firstDayDOW = (dow - (day - 1) % 7 + 7) % 7;
      secondSunday = (firstDayDOW == 0) ? 8 : (8 + (7 - firstDayDOW));
      
      if(day < secondSunday) return false;
      if(day > secondSunday) return true;
      // On the second Sunday, DST starts at 2 AM
      return (hour >= 2);
   }
   
   // November - DST ends on first Sunday
   if(month == 11)
   {
      // Find first Sunday: it's between day 1-7
      int firstDayDOW = (dow - (day - 1) % 7 + 7) % 7;
      int firstSunday = (firstDayDOW == 0) ? 1 : (8 - firstDayDOW);
      
      if(day < firstSunday) return true;
      if(day > firstSunday) return false;
      // On the first Sunday, DST ends at 2 AM
      return (hour < 2);
   }
   
   // December - No DST
   return false;
}

//+------------------------------------------------------------------+
//| Get Broker GMT Offset (Auto-Detect)                              |
//| Returns the broker server's offset from GMT in hours             |
//+------------------------------------------------------------------+
int GetBrokerGMTOffset()
{
   // Method 1: Use TimeGMT() vs TimeCurrent()
   // TimeGMT() returns actual GMT time
   // TimeCurrent() returns broker server time
   datetime serverTime = TimeCurrent();
   datetime gmtTime = TimeGMT();
   
   // Calculate difference in seconds, then convert to hours
   int offsetSeconds = (int)(serverTime - gmtTime);
   int offsetHours = (int)MathRound(offsetSeconds / 3600.0);
   
   return offsetHours;
}

//+------------------------------------------------------------------+
//| Get New York Hour from Server Time                               |
//| Auto-detects broker GMT offset                                   |
//+------------------------------------------------------------------+
int GetNewYorkHour(datetime serverTime)
{
   // Auto-detect broker's GMT offset
   int brokerGMTOffset = GetBrokerGMTOffset();
   
   // New York offset from GMT: -5 (EST) or -4 (EDT)
   int nyOffsetFromGMT = IsNewYorkDST(serverTime) ? -4 : -5;
   
   // Convert server time to New York time
   MqlDateTime dt;
   TimeToStruct(serverTime, dt);
   
   // Server hour -> GMT hour -> NY hour
   // GMT hour = Server hour - brokerGMTOffset
   // NY hour = GMT hour + nyOffsetFromGMT
   // NY hour = Server hour - brokerGMTOffset + nyOffsetFromGMT
   int nyHour = dt.hour - brokerGMTOffset + nyOffsetFromGMT;
   
   // Handle day wrap
   if(nyHour < 0) nyHour += 24;
   if(nyHour >= 24) nyHour -= 24;
   
   return nyHour;
}

//+------------------------------------------------------------------+
//| Get New York Time (full datetime)                                |
//+------------------------------------------------------------------+
datetime GetNewYorkTime()
{
   int brokerGMTOffset = GetBrokerGMTOffset();
   int nyOffsetFromGMT = IsNewYorkDST(TimeCurrent()) ? -4 : -5;
   
   // Convert broker time to NY time
   int totalOffsetSeconds = (nyOffsetFromGMT - brokerGMTOffset) * 3600;
   
   return TimeCurrent() + totalOffsetSeconds;
}

//+------------------------------------------------------------------+
//| Session Management (New York Time)                               |
//+------------------------------------------------------------------+
bool IsSessionActive()
{
   if(!shouldUseSessionManagement) {
      return true;
   }

   // Get current hour in New York time
   int nyHour = GetNewYorkHour(TimeCurrent());
   
   if(nyHour < SessionStartHour || nyHour >= SessionEndHour)
      return false;
   
   // Warn if too many trades
   if(SessionTradeCount >= MaxTradesPerSession)
   {
      StatusMessage = StringFormat("⚠️ Max trades reached: %d", SessionTradeCount);
      Print("⚠️ WARNING: Max trades per session reached!");
      Print("⚠️ Consider stopping EA to avoid broker complaints!");
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Daily Session Tracking                                          |
//+------------------------------------------------------------------+
datetime DayStart(datetime t)
{
   MqlDateTime st;
   TimeToStruct(t, st);
   st.hour = 0;
   st.min = 0;
   st.sec = 0;
   return StructToTime(st);
}

void CheckNewSession()
{
   datetime currentDay = DayStart(TimeCurrent());
   
   if(currentDay != CurrentSessionDay)
   {
      CurrentSessionDay = currentDay;
      SessionStartBalance = AccountInfoDouble(ACCOUNT_EQUITY);
      DailyLimitReached = false;
      SessionTradeCount = 0;
      
      Print("=== NEW TRADING SESSION ===");
      Print("Date: ", TimeToString(currentDay, TIME_DATE));
      Print("Starting Equity: $", DoubleToString(SessionStartBalance, 2));
   }
}

double GetDailyPNL()
{
   if(SessionStartBalance == 0.0) return 0.0;
   double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   return (currentEquity - SessionStartBalance);
}

bool CheckDailyLossLimit()
{
   if(!UseDailyLossLimit) return false;
   
   double dailyPNL = GetDailyPNL();
   double lossThreshold = -(SessionStartBalance * (DailyLossPercent / 100.0));
   
   if(dailyPNL <= lossThreshold && !DailyLimitReached)
   {
      DailyLimitReached = true;
      
      Print("════════════════════════════════════");
      Print("⚠️ DAILY LOSS LIMIT REACHED!");
      Print("════════════════════════════════════");
      Print("Daily P/L: $", DoubleToString(dailyPNL, 2));
      Print("Loss Limit: $", DoubleToString(lossThreshold, 2));
      Print("EA SHUT DOWN for today");
      Print("════════════════════════════════════");
      
      // Cancel all pending orders
      CancelAllOrders();
   }
   
   return DailyLimitReached;
}

//+------------------------------------------------------------------+
//| Calculate Commission from History                                |
//+------------------------------------------------------------------+
void CalculateCommissionFromHistory()
{
   if(!HistorySelect(0, TimeCurrent()))
      return;
   
   for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0) continue;
      
      if(HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol) continue;
      if(HistoryDealGetDouble(ticket, DEAL_PROFIT) == 0) continue;
      
      double entryPrice = HistoryDealGetDouble(ticket, DEAL_PRICE);
      ulong posID = HistoryDealGetInteger(ticket, DEAL_POSITION_ID);
      
      if(posID == 0) continue;
      
      // Find exit deal
      for(int j = i + 1; j < HistoryDealsTotal(); j++)
      {
         ulong exitTicket = HistoryDealGetTicket(j);
         if(HistoryDealGetInteger(exitTicket, DEAL_POSITION_ID) == posID)
         {
            double exitPrice = HistoryDealGetDouble(exitTicket, DEAL_PRICE);
            double profit = HistoryDealGetDouble(exitTicket, DEAL_PROFIT);
            double commission = HistoryDealGetDouble(exitTicket, DEAL_COMMISSION);
            
            if(exitPrice != entryPrice)
            {
               PriceToPipRatio = MathAbs(profit / (exitPrice - entryPrice));
               CommissionPerPip = -commission / PriceToPipRatio;
               return;
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Calculate Lot Size                                              |
//+------------------------------------------------------------------+
double CalculateLotSize()
{
   double lotSize = InpFixedLots;
   
   if(InpRiskMode == RISK_PERCENT)
   {
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      double riskAmount = equity * (InpRiskPercent / 100.0);
      double slDistance = CalculatedStopLoss / SymPoint;
      
      double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      
      if(tickSize > 0)
      {
         double pointValue = (tickValue / tickSize) * SymPoint;
         if(pointValue > 0)
            lotSize = riskAmount / (slDistance * pointValue);
      }
   }
   else if(InpRiskMode == RISK_DOLLAR)
   {
      double slDistance = CalculatedStopLoss / SymPoint;
      double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      
      if(tickSize > 0)
      {
         double pointValue = (tickValue / tickSize) * SymPoint;
         if(pointValue > 0)
            lotSize = InpRiskDollar / (slDistance * pointValue);
      }
   }
   
   // Normalize
   if(BrokerLotStep > 0)
      lotSize = MathFloor(lotSize / BrokerLotStep) * BrokerLotStep;
   
   lotSize = MathMax(lotSize, BrokerMinLot);
   lotSize = MathMin(lotSize, BrokerMaxLot);
   lotSize = MathMin(lotSize, InpMaxLotSize);
   
   return NormalizeDouble(lotSize, 2);
}

//+------------------------------------------------------------------+
//| Place Bracket Orders (Both Sides)                               |
//+------------------------------------------------------------------+
void PlaceBracketOrders()
{
   // Only place if no orders exist and conditions met
   if(TotalBuyCount > 0 || TotalSellCount > 0)
      return;
   
   // Check if enough time passed since last order
   if(TimeCurrent() - MathMax(LastBuyOrderTime, LastSellOrderTime) < ModificationInterval)
      return;
   
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   double lotSize = CalculateLotSize();
   
   // BUY STOP (above price)
   double buyPrice = NormalizeDouble(ask + AdjustedOrderDistance, SymDigits);
   double buySL = NormalizeDouble(buyPrice - CalculatedStopLoss, SymDigits);
   
   if(trade.BuyStop(lotSize, buyPrice, _Symbol, buySL, 0, ORDER_TIME_GTC, 0, "HFT_BUY"))
   {
      BuyOrderTicket = trade.ResultOrder();
      LastBuyOrderTime = TimeCurrent();
      SessionTradeCount++;
      Print("✅ BUY STOP placed at ", buyPrice);
   }
   
   // SELL STOP (below price)
   double sellPrice = NormalizeDouble(bid - AdjustedOrderDistance, SymDigits);
   double sellSL = NormalizeDouble(sellPrice + CalculatedStopLoss, SymDigits);
   
   if(trade.SellStop(lotSize, sellPrice, _Symbol, sellSL, 0, ORDER_TIME_GTC, 0, "HFT_SELL"))
   {
      SellOrderTicket = trade.ResultOrder();
      LastSellOrderTime = TimeCurrent();
      SessionTradeCount++;
      Print("✅ SELL STOP placed at ", sellPrice);
   }
}

//+------------------------------------------------------------------+
//| Modify Pending Orders                                            |
//+------------------------------------------------------------------+
void ModifyPendingOrders()
{
   if(TimeCurrent() - LastModificationTime < ModificationInterval)
      return;
   
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Modify BUY STOP
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!orderInfo.SelectByIndex(i)) continue;
      if(orderInfo.Magic() != InpMagic) continue;
      if(orderInfo.Symbol() != _Symbol) continue;
      
      if(orderInfo.OrderType() == ORDER_TYPE_BUY_STOP)
      {
         double currentPrice = orderInfo.PriceOpen();
         double newPrice = NormalizeDouble(ask + AdjustedOrderDistance, SymDigits);
         
         if(MathAbs(newPrice - currentPrice) > AdjustedOrderDistance * 0.1)
         {
            double newSL = NormalizeDouble(newPrice - CalculatedStopLoss, SymDigits);
            if(trade.OrderModify(orderInfo.Ticket(), newPrice, newSL, 0, ORDER_TIME_GTC, 0))
            {
               LastModificationTime = TimeCurrent();
               Print("🔄 BUY STOP modified to ", newPrice);
            }
         }
      }
      
      if(orderInfo.OrderType() == ORDER_TYPE_SELL_STOP)
      {
         double currentPrice = orderInfo.PriceOpen();
         double newPrice = NormalizeDouble(bid - AdjustedOrderDistance, SymDigits);
         
         if(MathAbs(newPrice - currentPrice) > AdjustedOrderDistance * 0.1)
         {
            double newSL = NormalizeDouble(newPrice + CalculatedStopLoss, SymDigits);
            if(trade.OrderModify(orderInfo.Ticket(), newPrice, newSL, 0, ORDER_TIME_GTC, 0))
            {
               LastModificationTime = TimeCurrent();
               Print("🔄 SELL STOP modified to ", newPrice);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Manage Open Positions (Aggressive Trailing)                     |
//+------------------------------------------------------------------+
void ManageOpenPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!positionInfo.SelectByIndex(i)) continue;
      if(positionInfo.Magic() != InpMagic) continue;
      if(positionInfo.Symbol() != _Symbol) continue;
      
      // Cancel opposite order when position opens
      if(positionInfo.PositionType() == POSITION_TYPE_BUY)
      {
         CancelSellOrders();
         AggressiveTrailing(positionInfo.Ticket(), true);
      }
      else
      {
         CancelBuyOrders();
         AggressiveTrailing(positionInfo.Ticket(), false);
      }
   }
}

//+------------------------------------------------------------------+
//| Aggressive Trailing Stop                                         |
//+------------------------------------------------------------------+
void AggressiveTrailing(ulong ticket, bool isBuy)
{
   if(!positionInfo.SelectByTicket(ticket)) return;
   
   double openPrice = positionInfo.PriceOpen();
   double currentPrice = positionInfo.PriceCurrent();
   double currentSL = positionInfo.StopLoss();
   
   double priceMove = isBuy ? (currentPrice - openPrice + CommissionPerPip) 
                            : (openPrice - currentPrice - CommissionPerPip);
   
   // Only trail if profit > Kost
   if(priceMove < TrailingStopActive) return;
   
   // Calculate trail distance
   double trailDistance = TrailingStopActive;
   
   double newSL;
   if(isBuy)
   {
      newSL = NormalizeDouble(currentPrice - trailDistance, SymDigits);
      if(currentSL == 0 || newSL > currentSL)
      {
         if(trade.PositionModify(ticket, newSL, 0))
            Print("✅ BUY trail: ", newSL);
      }
   }
   else
   {
      newSL = NormalizeDouble(currentPrice + trailDistance, SymDigits);
      if(currentSL == 0 || newSL < currentSL)
      {
         if(trade.PositionModify(ticket, newSL, 0))
            Print("✅ SELL trail: ", newSL);
      }
   }
}

//+------------------------------------------------------------------+
//| Check for Scale In                                               |
//+------------------------------------------------------------------+
void CheckForScaleIn()
{
   if(!EnableScaling) return;
   
   // Scale into BUY positions
   if(OpenBuyCount > 0 && OpenBuyCount < MaxScalePositions)
   {
      // Only scale if original SL hasn't started trailing
      bool originalSLActive = (CurrentBuyStopLoss > 0);
      
      if(originalSLActive && TotalBuyCount < MaxScalePositions)
      {
         double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double buyPrice = NormalizeDouble(ask + AdjustedOrderDistance, SymDigits);
         double buySL = NormalizeDouble(buyPrice - CalculatedStopLoss, SymDigits);
         double lotSize = CalculateLotSize();
         
         if(trade.BuyStop(lotSize, buyPrice, _Symbol, buySL, 0, ORDER_TIME_GTC, 0, "HFT_SCALE_BUY"))
         {
            SessionTradeCount++;
            Print("📈 SCALE IN: BUY STOP placed");
         }
      }
   }
   
   // Scale into SELL positions
   if(OpenSellCount > 0 && OpenSellCount < MaxScalePositions)
   {
      bool originalSLActive = (CurrentSellStopLoss > 0);
      
      if(originalSLActive && TotalSellCount < MaxScalePositions)
      {
         double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double sellPrice = NormalizeDouble(bid - AdjustedOrderDistance, SymDigits);
         double sellSL = NormalizeDouble(sellPrice + CalculatedStopLoss, SymDigits);
         double lotSize = CalculateLotSize();
         
         if(trade.SellStop(lotSize, sellPrice, _Symbol, sellSL, 0, ORDER_TIME_GTC, 0, "HFT_SCALE_SELL"))
         {
            SessionTradeCount++;
            Print("📉 SCALE IN: SELL STOP placed");
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Cancel Buy Orders                                                |
//+------------------------------------------------------------------+
void CancelBuyOrders()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!orderInfo.SelectByIndex(i)) continue;
      if(orderInfo.Magic() != InpMagic) continue;
      if(orderInfo.Symbol() != _Symbol) continue;
      
      if(orderInfo.OrderType() == ORDER_TYPE_BUY_STOP)
      {
         if(trade.OrderDelete(orderInfo.Ticket()))
         {
            Print("❌ BUY STOP cancelled (opposite filled)");
            BuyOrderTicket = 0;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Cancel Sell Orders                                               |
//+------------------------------------------------------------------+
void CancelSellOrders()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!orderInfo.SelectByIndex(i)) continue;
      if(orderInfo.Magic() != InpMagic) continue;
      if(orderInfo.Symbol() != _Symbol) continue;
      
      if(orderInfo.OrderType() == ORDER_TYPE_SELL_STOP)
      {
         if(trade.OrderDelete(orderInfo.Ticket()))
         {
            Print("❌ SELL STOP cancelled (opposite filled)");
            SellOrderTicket = 0;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Cancel All Orders                                                |
//+------------------------------------------------------------------+
void CancelAllOrders()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!orderInfo.SelectByIndex(i)) continue;
      if(orderInfo.Magic() != InpMagic) continue;
      if(orderInfo.Symbol() != _Symbol) continue;
      
      trade.OrderDelete(orderInfo.Ticket());
   }
   
   BuyOrderTicket = 0;
   SellOrderTicket = 0;
}

//+------------------------------------------------------------------+
//| Update Chart Display                                             |
//+------------------------------------------------------------------+
void UpdateChartDisplay()
{
   string display = "";
   
   display += "═══════════════════════════════════\n";
   display += "    HFT BRACKET PRO - STATUS\n";
   display += "═══════════════════════════════════\n\n";
   
   // Broker Info
   int brokerOffset = GetBrokerGMTOffset();
   display += StringFormat("Broker GMT: %+d\n", brokerOffset);
   
   // New York Time Display
   int nyHour = GetNewYorkHour(TimeCurrent());
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   string dstStatus = IsNewYorkDST(TimeCurrent()) ? "EDT" : "EST";
   display += StringFormat("NY Time: %02d:%02d %s\n", nyHour, dt.min, dstStatus);
   display += StringFormat("Session: %02d:00 - %02d:00 NY\n\n", SessionStartHour, SessionEndHour);
   
   // EA Status
   display += "Status: " + StatusMessage + "\n";
   
   // Daily P/L
   double dailyPNL = GetDailyPNL();
   double dailyPercent = (SessionStartBalance > 0) ? (dailyPNL / SessionStartBalance) * 100.0 : 0;
   
   display += StringFormat("Daily P/L: $%.2f (%.2f%%)\n", dailyPNL, dailyPercent);
   
   if(DailyLimitReached)
      display += "⚠️ DAILY LIMIT REACHED - EA STOPPED\n";
   
   display += "\n";
   
   // Position Info
   display += StringFormat("Open Positions: BUY=%d SELL=%d\n", OpenBuyCount, OpenSellCount);
   display += StringFormat("Session Trades: %d", SessionTradeCount);
   
   if(SessionTradeCount >= MaxTradesPerSession)
      display += " ⚠️ MAX REACHED!";
   
   display += "\n\n";
   
   // Spread Info
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double spreadPercent = (CurrentSpread / currentPrice) * 100.0;
   display += StringFormat("Spread: %.4f%% ", spreadPercent);
   
   if(spreadPercent > MaxSpreadPercent)
      display += "❌ TOO WIDE";
   else
      display += "✅";
   
   display += "\n";
   
   // Filter Status - FIXED!
   if(VWAPFilterActive)
      display += "VWAP: ON\n";
   if(ATRFilterActive)
      display += "ATR: ON (M1)\n";
   if(ADXFilterActive)
      display += "ADX: ON\n";
   
   display += "\n═══════════════════════════════════";
   
   Comment(display);
}
//+------------------------------------------------------------------+