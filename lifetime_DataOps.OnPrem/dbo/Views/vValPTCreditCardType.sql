CREATE VIEW dbo.vValPTCreditCardType AS 
SELECT ValPTCreditCardTypeID,Description,SortOrder,CardType
FROM MMS.dbo.ValPTCreditCardType WITH(NOLOCK)
