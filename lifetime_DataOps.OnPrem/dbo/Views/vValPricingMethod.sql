CREATE VIEW dbo.vValPricingMethod AS 
SELECT ValPricingMethodID,Description,SortOrder,InsertedDateTime,UpdatedDateTime
FROM MMS.dbo.ValPricingMethod WITH(NOLOCK)
