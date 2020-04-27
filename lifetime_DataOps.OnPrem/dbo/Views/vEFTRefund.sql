CREATE VIEW dbo.vEFTRefund AS 
SELECT EFTRefundID,EFTID,OriginalMMSTranID,OriginalTranItemID,OriginalDrawerActivityID,RefundAmount,RefundTaxAmount,ReasonCodeID,ProductID
FROM MMS_Archive.dbo.EFTRefund WITH(NOLOCK)
