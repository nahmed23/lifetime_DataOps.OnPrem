CREATE VIEW dbo.vValProductStatus AS 
SELECT ValProductStatusID,Description,SortOrder
FROM MMS.dbo.ValProductStatus WITH(NOLOCK)
