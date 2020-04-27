CREATE VIEW dbo.vValKeyAction AS 
SELECT ValKeyActionID,Description,SortOrder,InsertedDateTime,UpdatedDateTime
FROM MMS.dbo.ValKeyAction WITH(NOLOCK)
