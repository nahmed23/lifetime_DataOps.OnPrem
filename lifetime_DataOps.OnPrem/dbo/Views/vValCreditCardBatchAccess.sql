CREATE VIEW dbo.vValCreditCardBatchAccess AS 
SELECT ValCreditCardBatchAccessID,Description,SortOrder
FROM MMS.dbo.ValCreditCardBatchAccess WITH(NOLOCK)
