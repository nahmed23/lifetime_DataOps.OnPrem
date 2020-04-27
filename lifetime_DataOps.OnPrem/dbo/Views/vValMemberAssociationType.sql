CREATE VIEW dbo.vValMemberAssociationType AS 
SELECT ValMemberAssociationTypeID,Description,SortOrder,InsertedDateTime,UpdatedDateTime
FROM MMS.dbo.ValMemberAssociationType WITH(NOLOCK)
