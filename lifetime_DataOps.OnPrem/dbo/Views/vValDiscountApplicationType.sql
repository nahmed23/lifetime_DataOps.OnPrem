CREATE VIEW dbo.vValDiscountApplicationType AS 
SELECT ValDiscountApplicationTypeID,Description,SortOrder
FROM MMS.dbo.ValDiscountApplicationType WITH(NOLOCK)
