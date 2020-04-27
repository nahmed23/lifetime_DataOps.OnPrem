
CREATE VIEW dbo.vValMembershipStatus AS 
SELECT ValMembershipStatusID,Description,SortOrder,ValMembershipMessageTypeID
FROM MMS.dbo.ValMembershipStatus WITH (NoLock)

