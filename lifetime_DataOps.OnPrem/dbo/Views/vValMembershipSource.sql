
CREATE VIEW dbo.vValMembershipSource AS 
SELECT ValMembershipSourceID,Description,SortOrder
FROM MMS.dbo.ValMembershipSource WITH (NoLock)

