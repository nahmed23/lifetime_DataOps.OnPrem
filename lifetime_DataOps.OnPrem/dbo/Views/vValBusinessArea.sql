CREATE VIEW dbo.vValBusinessArea AS 
SELECT ValBusinessAreaID,Description,SortOrder
FROM MMS.dbo.ValBusinessArea WITH(NOLOCK)
