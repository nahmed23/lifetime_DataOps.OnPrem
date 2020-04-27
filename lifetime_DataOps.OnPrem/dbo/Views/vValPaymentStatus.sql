CREATE VIEW dbo.vValPaymentStatus AS 
SELECT ValPaymentStatusID,Description,SortOrder
FROM MMS.dbo.ValPaymentStatus WITH(NOLOCK)
