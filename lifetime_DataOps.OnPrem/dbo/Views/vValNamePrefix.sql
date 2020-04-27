
CREATE VIEW dbo.vValNamePrefix AS 
SELECT ValNamePrefixID,Description,SortOrder
FROM MMS.dbo.ValNamePrefix WITH (NoLock)

