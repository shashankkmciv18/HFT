//+------------------------------------------------------------------+
//|                                                          HFT.mq5 |
//|                      High-Frequency Bracket Scalping EA          |
//|                Based on YouTube Logic + Professional Features    |
//| 03.02.2026 - Initial release (Modular Version)                   |
//+------------------------------------------------------------------+
#property copyright "HFT Bracket Pro - Professional Edition"
#property link      "https://mql5.com"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Include Modular Files                                            |
//+------------------------------------------------------------------+
#include "HFT_Inputs.mqh"           // Input parameters & enums
#include "HFT_Globals.mqh"          // Global variables & trade objects
#include "HFT_SymbolUtils.mqh"      // Symbol & spread utilities
#include "HFT_Filters.mqh"          // VWAP, ATR, ADX, Spread filters
#include "HFT_Session.mqh"          // Session & daily loss management
#include "HFT_RiskManagement.mqh"   // Lot size & commission calculation
#include "HFT_Orders.mqh"           // Order placement & modification
#include "HFT_Positions.mqh"        // Position management & trailing
#include "HFT_Display.mqh"          // Chart display functions

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Set magic number
   trade.SetExpertMagicNumber(InpMagic);
   
   // Remove grid from chart
   ChartSetInteger(0, CHART_SHOW_GRID, false);
   
   // Initialize symbol parameters
   UpdateSymbolParameters();
   
   // Initialize broker limits
   InitializeBrokerLimits();
   
   // Initialize spread array
   InitializeSpreadArray();
   
   // Initialize filters (VWAP, ATR, ADX)
   InitializeFilters();
   
   // Initialize daily session
   InitializeSession();
   
   // Calculate commission from history
   CalculateCommissionFromHistory();
   
   // Initialize trailing values
   BaseTrailingStop = Kost;
   TrailingStopIncrement = Kost;
   
   // Log initialization info
   LogInitialization();
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Release indicator handles
   ReleaseFilters();
   
   // Clear chart display
   ClearChartDisplay();
   
   // Log deinitialization
   LogDeinitialization(reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Check for new session (daily reset)
   CheckNewSession();
   
   // Check daily loss limit
   if(CheckDailyLossLimit())
   {
      UpdateChartDisplay();
      return;
   }
   
   // Check if trading session is active
   if(!IsSessionActive())
   {
      TradingAllowed = false;
      StatusMessage = "Outside trading hours";
      UpdateChartDisplay();
      return;
   }
   
   // Update symbol parameters
   UpdateSymbolParameters();
   
   // Update spread tracking
   UpdateSpread();
   
   // Calculate order distances
   CalculateDistances();
   
   // Count positions and orders
   CountPositions();
   
   // Check all filters (spread, VWAP, ATR, ADX)
   if(!PassAllFilters())
   {
      UpdateChartDisplay();
      return;
   }
   
   TradingAllowed = true;
   StatusMessage = "Trading ACTIVE";
   
   //+------------------------------------------------------------------+
   //| Main Trading Logic                                               |
   //+------------------------------------------------------------------+
   
   // 1. Trail existing positions
   ManageOpenPositions();
   
   // 2. Adjust pending orders
   ModifyPendingOrders();
   
   // 3. Place new bracket orders
   PlaceBracketOrders();
   
   // 4. Add scale-in positions if enabled
   CheckForScaleIn();
   
   // Update chart display
   UpdateChartDisplay();
}
//+------------------------------------------------------------------+
