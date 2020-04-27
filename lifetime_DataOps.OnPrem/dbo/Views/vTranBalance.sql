

/****** Object:  View [dbo].[vTranBalance]    Script Date: 12/1/2014 6:18:45 PM ******/
CREATE VIEW [dbo].[vTranBalance] AS SELECT TranBalanceID,TranItemID,MembershipID,OriginalAmount,TranBalanceAmount,ProcessedFlag,TranProductCategory,
InsertedDateTime 
FROM MMS.dbo.TranBalance With (NOLOCK)
