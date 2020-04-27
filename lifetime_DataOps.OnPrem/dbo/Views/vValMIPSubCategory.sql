
CREATE VIEW dbo.vValMIPSubCategory AS 
SELECT ValMIPSubCategoryID,Description,SortOrder
FROM MMS.dbo.ValMIPSubCategory WITH (NoLock)

