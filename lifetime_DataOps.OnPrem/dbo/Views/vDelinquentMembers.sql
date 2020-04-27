


CREATE VIEW dbo.vDelinquentMembers
	 (MembershipID)
   AS SELECT  DISTINCT(vMMSTran.MembershipID)
   FROM  dbo.vMMSTran 		vMMSTran 
	,dbo.vTranBalance 	vTranBalance 
	,dbo.vTranItem 		vTranItem 
  WHERE vMMSTran.MMSTranID	= vTranItem.MMSTranID 
    AND vTranBalance.TranItemID	= vTranItem.TranItemID 
    AND (vMMSTran.PostDateTime	< DATEADD(day,-30,getdate())
    ANd  vTranBalance.TranBalanceAmount > 0)


