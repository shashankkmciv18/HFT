//+------------------------------------------------------------------+
//|                                                   HFT_Orders.mqh |
//|                                         Copyright 2026, YourName |
//|                                                 https://mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, YourName"
#property link      "https://mql5.com"

#ifndef HFT_ORDERS_MQH
#define HFT_ORDERS_MQH

#include "HFT_Globals.mqh"
#include "HFT_Inputs.mqh"
#include "HFT_RiskManagement.mqh"

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
//| Place Bracket Orders (Both Sides)                                |
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
   
   // Modify BUY STOP and SELL STOP
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

#endif // HFT_ORDERS_MQH
//+------------------------------------------------------------------+
