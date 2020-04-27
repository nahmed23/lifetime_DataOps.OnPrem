CREATE VIEW dbo.vValMembershipTypeGroup AS 
SELECT ValMembershipTypeGroupID,Description,SortOrder,InsertedDateTime,UpdatedDateTime,ValCardLevelID
FROM MMS.dbo.ValMembershipTypeGroup WITH(NOLOCK)
