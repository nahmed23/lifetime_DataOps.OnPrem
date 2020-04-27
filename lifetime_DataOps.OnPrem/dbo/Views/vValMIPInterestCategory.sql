CREATE VIEW dbo.vValMIPInterestCategory AS 
SELECT ValMIPInterestCategoryID,Description,SortOrder
FROM MMS.dbo.ValMIPInterestCategory WITH(NOLOCK)
