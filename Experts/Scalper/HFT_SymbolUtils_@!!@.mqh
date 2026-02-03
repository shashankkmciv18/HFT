//+------------------------------------------------------------------+
//|                                              HFT_SymbolUtils.mqh |
//|                                         Copyright 2026, YourName |
//|                                                 https://mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, YourName"
#property link      "https://mql5.com"

#ifndef HFT_SYMBOLUTILS_MQH
#define HFT_SYMBOLUTILS_MQH

#include "HFT_Globals.mqh"
#include "HFT_Inputs.mqh"

//+------------------------------------------------------------------+
//| Update Symbol Parameters                                         |
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
//| Initialize Broker Limits                                         |
//+------------------------------------------------------------------+
void InitializeBrokerLimits()
{
   BrokerMinLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   BrokerMaxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   BrokerLotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
}

//+------------------------------------------------------------------+
//| Update Spread Tracking                                           |
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
//| Initialize Spread Array                                          |
//+------------------------------------------------------------------+
void InitializeSpreadArray()
{
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
}

//+------------------------------------------------------------------+
//| Calculate Distances                                              |
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

#endif // HFT_SYMBOLUTILS_MQH
//+------------------------------------------------------------------+
