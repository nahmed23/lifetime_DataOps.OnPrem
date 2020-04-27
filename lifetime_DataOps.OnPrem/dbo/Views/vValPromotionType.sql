
CREATE VIEW dbo.vValPromotionType AS 
SELECT ValPromotionTypeID,Description,SortOrder
FROM MMS.dbo.ValPromotionType WITH(NOLOCK)

