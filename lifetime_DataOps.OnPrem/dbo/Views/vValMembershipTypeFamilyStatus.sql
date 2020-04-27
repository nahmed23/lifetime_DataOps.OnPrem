
CREATE VIEW dbo.vValMembershipTypeFamilyStatus AS 
SELECT ValMembershipTypeFamilyStatusID,Description,SortOrder
FROM MMS.dbo.ValMembershipTypeFamilyStatus WITH (NoLock)

