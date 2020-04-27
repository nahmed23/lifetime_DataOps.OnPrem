


CREATE VIEW dbo.vCommissionSplitCalc 
         (TranItemID
	 ,CommissionCount)
AS SELECT TranItem.TranItemID			
         ,COUNT(SaleCommission.SaleCommissionID)	   
  FROM vSaleCommission	SaleCommission
      ,vTranItem	TranItem
 WHERE TranItem.TranItemID	= SaleCommission.TranItemID
GROUP BY TranItem.TranItemID 


