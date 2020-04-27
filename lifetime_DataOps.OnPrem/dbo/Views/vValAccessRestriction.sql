CREATE VIEW dbo.vValAccessRestriction AS 
SELECT ValAccessRestrictionID,Description,SortOrder,InsertedDateTime,UpdatedDateTime
FROM MMS.dbo.ValAccessRestriction WITH(NOLOCK)
