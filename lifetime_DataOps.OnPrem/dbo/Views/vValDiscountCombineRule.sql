CREATE VIEW dbo.vValDiscountCombineRule AS 
SELECT ValDiscountCombineRuleID,Description,SortOrder
FROM MMS.dbo.ValDiscountCombineRule WITH(NOLOCK)
