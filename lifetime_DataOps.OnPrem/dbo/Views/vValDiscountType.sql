CREATE VIEW dbo.vValDiscountType AS 
SELECT ValDiscountTypeID,Description,SortOrder
FROM MMS.dbo.ValDiscountType WITH(NOLOCK)
