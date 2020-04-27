CREATE VIEW dbo.vValRestrictedGroup AS 
SELECT ValRestrictedGroupID,Description,SortOrder,InsertedDateTime,UpdatedDateTime
FROM MMS.dbo.ValRestrictedGroup WITH(NOLOCK)
