CREATE VIEW dbo.vValCardLevel AS 
SELECT ValCardLevelID,Description,SortOrder,InsertedDateTime,UpdatedDateTime
FROM MMS.dbo.ValCardLevel WITH(NOLOCK)
