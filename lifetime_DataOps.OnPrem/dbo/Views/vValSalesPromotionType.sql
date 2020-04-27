CREATE VIEW dbo.vValSalesPromotionType AS 
SELECT ValSalesPromotionTypeID,Description,SortOrder
FROM MMS.dbo.ValSalesPromotionType WITH(NOLOCK)
