
CREATE VIEW [dbo].[vPayment] AS SELECT PaymentID,ValPaymentTypeID,PaymentAmount,ApprovalCode,MMSTranID,TipAmount 
FROM MMS_Archive.dbo.Payment With (NOLOCK)
