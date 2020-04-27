CREATE VIEW dbo.vValPricingRule AS 
SELECT ValPricingRuleID,Description,SortOrder,InsertedDateTime,UpdatedDateTime
FROM MMS.dbo.ValPricingRule WITH(NOLOCK)
