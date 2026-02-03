//+------------------------------------------------------------------+
//|                                                  HFT_Filters.mqh |
//|                                         Copyright 2026, YourName |
//|                                                 https://mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, YourName"
#property link      "https://mql5.com"

#ifndef HFT_FILTERS_MQH
#define HFT_FILTERS_MQH

#include "HFT_Globals.mqh"
#include "HFT_Inputs.mqh"

//+------------------------------------------------------------------+
//| Initialize Filters                                               |
//+------------------------------------------------------------------+
void InitializeFilters()
{
   // Initialize VWAP
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
   
   // Initialize ATR (M1 for scalping!)
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
   
   // Initialize ADX
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
}

//+------------------------------------------------------------------+
//| Release Filter Indicators                                        |
//+------------------------------------------------------------------+
void ReleaseFilters()
{
   if(VWAPHandle != INVALID_HANDLE) IndicatorRelease(VWAPHandle);
   if(ATRHandle != INVALID_HANDLE) IndicatorRelease(ATRHandle);
   if(ADXHandle != INVALID_HANDLE) IndicatorRelease(ADXHandle);
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
//| Professional Filter Suite - Check All Filters                    |
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
   
   // VWAP filter
   if(VWAPFilterActive && !CheckVWAPFilter())
   {
      return false;
   }
   
   // ATR filter
   if(ATRFilterActive && !CheckATRFilter())
   {
      return false;
   }
   
   // ADX filter
   if(ADXFilterActive && !CheckADXFilter())
   {
      return false;
   }
   
   return true;
}

#endif // HFT_FILTERS_MQH
//+------------------------------------------------------------------+
