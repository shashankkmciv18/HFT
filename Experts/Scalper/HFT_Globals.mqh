//+------------------------------------------------------------------+
//|                                                  HFT_Globals.mqh |
//|                                         Copyright 2026, YourName |
//|                                                 https://mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, YourName"
#property link      "https://mql5.com"

#ifndef HFT_GLOBALS_MQH
#define HFT_GLOBALS_MQH

#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>
#include <Trade/OrderInfo.mqh>

//+------------------------------------------------------------------+
//| Global Trade Objects                                             |
//+------------------------------------------------------------------+
CTrade trade;
CPositionInfo positionInfo;
COrderInfo orderInfo;

//+------------------------------------------------------------------+
//| Symbol Parameters                                                |
//+------------------------------------------------------------------+
double SymPoint;
int    SymDigits;
double MinStopDistance;
double MinFreezeDistance;

//+------------------------------------------------------------------+
//| Broker Limits                                                    |
//+------------------------------------------------------------------+
double BrokerMinLot;
double BrokerMaxLot;
double BrokerLotStep;

//+------------------------------------------------------------------+
//| Spread Tracking                                                  |
//+------------------------------------------------------------------+
double CurrentSpread;
double AverageSpread;
double SpreadArray[];
int    SpreadArraySize = 30;

//+------------------------------------------------------------------+
//| Order Tracking                                                   |
//+------------------------------------------------------------------+
ulong  BuyOrderTicket = 0;
ulong  SellOrderTicket = 0;
datetime LastBuyOrderTime = 0;
datetime LastSellOrderTime = 0;
datetime LastModificationTime = 0;

//+------------------------------------------------------------------+
//| Position Tracking                                                |
//+------------------------------------------------------------------+
double LowestBuyPrice = 0;
double HighestSellPrice = 0;
double CurrentBuyStopLoss = 0;
double CurrentSellStopLoss = 0;
int    OpenBuyCount = 0;
int    OpenSellCount = 0;
int    TotalBuyCount = 0;
int    TotalSellCount = 0;

//+------------------------------------------------------------------+
//| Trailing Stop                                                    |
//+------------------------------------------------------------------+
double BaseTrailingStop;
double TrailingStopIncrement;

//+------------------------------------------------------------------+
//| Daily Session Tracking                                           |
//+------------------------------------------------------------------+
double   SessionStartBalance = 0.0;
datetime CurrentSessionDay = 0;
bool     DailyLimitReached = false;
int      SessionTradeCount = 0;

//+------------------------------------------------------------------+
//| Indicator Handles                                                |
//+------------------------------------------------------------------+
int      VWAPHandle = INVALID_HANDLE;
int      ATRHandle = INVALID_HANDLE;
int      ADXHandle = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Filter Flags (can be modified at runtime)                        |
//+------------------------------------------------------------------+
bool     VWAPFilterActive = false;
bool     ATRFilterActive = false;
bool     ADXFilterActive = false;

//+------------------------------------------------------------------+
//| Calculated Values                                                |
//+------------------------------------------------------------------+
double   AdjustedOrderDistance;
double   MaxOrderPlacementDistance;
double   CalculatedStopLoss;
double   TrailingStopActive;
double   TrailingStopMax;

//+------------------------------------------------------------------+
//| Commission Tracking                                              |
//+------------------------------------------------------------------+
double   CommissionPerPip = 0;
double   PriceToPipRatio = 0;

//+------------------------------------------------------------------+
//| Status                                                           |
//+------------------------------------------------------------------+
bool     TradingAllowed = false;
string   StatusMessage = "";

//+------------------------------------------------------------------+
//| Time-Based Statistics Tracking                                   |
//+------------------------------------------------------------------+
// Trade timestamps array (circular buffer)
#define MAX_TRADE_HISTORY 500
datetime TradeTimestamps[];
double   TradePNLs[];
int      TradeHistoryCount = 0;
int      TradeHistoryIndex = 0;

// Order timestamps array (circular buffer)
#define MAX_ORDER_HISTORY 1000
datetime OrderPlacedTimestamps[];
datetime OrderModifiedTimestamps[];
int      OrderPlacedCount = 0;
int      OrderModifiedCount = 0;
int      OrderPlacedIndex = 0;
int      OrderModifiedIndex = 0;

// Cumulative totals
int      TotalTradesAllTime = 0;
int      TotalOrdersPlaced = 0;
int      TotalOrdersModified = 0;

#endif // HFT_GLOBALS_MQH
//+------------------------------------------------------------------+
