CREATE VIEW dbo.vValPTCreditCardActionCode AS 
SELECT ValPTCreditCardActionCodeID,Description,SortOrder,ActionCode
FROM MMS.dbo.ValPTCreditCardActionCode WITH(NOLOCK)
