CREATE VIEW dbo.vValOwnershipType AS 
SELECT ValOwnershipTypeID,Description,SortOrder,InsertedDateTime,UpdatedDateTime
FROM MMS.dbo.ValOwnershipType WITH(NOLOCK)
