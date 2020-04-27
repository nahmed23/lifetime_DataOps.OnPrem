CREATE VIEW dbo.vValSecurityGroup AS 
SELECT ValSecurityGroupID,Description,SortOrder,InsertedDateTime,UpdatedDateTime,UniqueMemberFlag
FROM MMS.dbo.ValSecurityGroup WITH(NOLOCK)
