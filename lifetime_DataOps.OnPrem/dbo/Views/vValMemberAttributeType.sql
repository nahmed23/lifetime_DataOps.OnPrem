CREATE VIEW dbo.vValMemberAttributeType AS 
SELECT ValMemberAttributeTypeID,Description,SortOrder,InsertedDateTime,UpdatedDateTime
FROM MMS.dbo.ValMemberAttributeType WITH(NOLOCK)
