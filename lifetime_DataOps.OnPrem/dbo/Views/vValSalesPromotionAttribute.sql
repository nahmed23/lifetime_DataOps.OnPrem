CREATE VIEW dbo.vValSalesPromotionAttribute AS 
SELECT ValSalesPromotionAttributeID,Description,SortOrder
FROM MMS.dbo.ValSalesPromotionAttribute WITH(NOLOCK)
