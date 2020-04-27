


CREATE VIEW dbo.vCommissionSplit          
	 (MMSTranID
	 ,TranItemID
	 ,PostDateTime)
AS SELECT MMSTran.MMSTranID
	 ,SaleCommission.TranItemID	 
	 ,ISNULL(MMSTran.PostDateTime,MMSTran.TranDate)			   
  FROM vSaleCommission	SaleCommission
      ,vMMSTran		MMSTran
      ,vTranItem	TranItem
 WHERE MMSTran.MMSTranID 	= TranItem.MMSTranID
   AND TranItem.TranItemID	= SaleCommission.TranItemID
UNION
   SELECT -10,-10,Null 


