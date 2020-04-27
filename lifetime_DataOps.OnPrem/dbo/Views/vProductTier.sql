CREATE VIEW dbo.vProductTier AS 
SELECT ProductTierID,Description,DisplayText,ProductID,ValProductTierTypeID,SortOrder,DisplayUIFlag,InsertedDateTime,UpdatedDateTime
FROM MMS.dbo.ProductTier WITH(NOLOCK)
