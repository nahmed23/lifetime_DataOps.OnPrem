CREATE VIEW dbo.vValRelationshipType AS 
SELECT ValRelationshipTypeID,Description,SortOrder,InsertedDateTime,UpdatedDateTime
FROM MMS.dbo.ValRelationshipType WITH(NOLOCK)
