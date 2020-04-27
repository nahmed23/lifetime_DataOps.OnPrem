CREATE VIEW dbo.vValCreditCardBatchStatus AS 
SELECT ValCreditCardBatchStatusID,Description,SortOrder
FROM MMS.dbo.ValCreditCardBatchStatus WITH(NOLOCK)
