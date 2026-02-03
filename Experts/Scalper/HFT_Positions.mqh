//+------------------------------------------------------------------+
//|                                                HFT_Positions.mqh |
//|                                         Copyright 2026, YourName |
//|                                                 https://mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, YourName"
#property link      "https://mql5.com"

#ifndef HFT_POSITIONS_MQH
#define HFT_POSITIONS_MQH

#include "HFT_Globals.mqh"
#include "HFT_Inputs.mqh"
#include "HFT_Orders.mqh"

//+------------------------------------------------------------------+
//| Count Open Positions and Orders                                  |
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
//| Manage Open Positions (Aggressive Trailing)                      |
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

#endif // HFT_POSITIONS_MQH
//+------------------------------------------------------------------+
