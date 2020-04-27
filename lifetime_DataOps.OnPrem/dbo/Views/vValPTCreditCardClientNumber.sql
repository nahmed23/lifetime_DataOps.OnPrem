CREATE VIEW dbo.vValPTCreditCardClientNumber AS 
SELECT ValPTCreditCardClientNumberID,Description,SortOrder,ClientNumber
FROM MMS.dbo.ValPTCreditCardClientNumber WITH(NOLOCK)
