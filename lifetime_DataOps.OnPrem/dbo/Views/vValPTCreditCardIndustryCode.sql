CREATE VIEW dbo.vValPTCreditCardIndustryCode AS 
SELECT ValPTCreditCardIndustryCodeID,Description,SortOrder,IndustryCode
FROM MMS.dbo.ValPTCreditCardIndustryCode WITH(NOLOCK)
