CREATE VIEW dbo.vValPOSPaymentTypeAccessType AS 
SELECT ValPOSPaymentTypeAccessTypeID,Description,SortOrder
FROM MMS.dbo.ValPOSPaymentTypeAccessType WITH(NOLOCK)
