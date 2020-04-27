
CREATE VIEW dbo.vValMemberType AS 
SELECT ValMemberTypeID,Description,SortOrder
FROM MMS.dbo.ValMemberType WITH (NoLock)

