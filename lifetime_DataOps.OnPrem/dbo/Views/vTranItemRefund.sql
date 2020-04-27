CREATE VIEW dbo.vTranItemRefund AS 
SELECT TranItemRefundID,TranItemID,OriginalTranItemID
FROM MMS_Archive.dbo.TranItemRefund WITH(NOLOCK)
