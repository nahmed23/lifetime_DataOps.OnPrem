
CREATE VIEW dbo.vValMemberCardStatus AS 
SELECT ValMemberCardStatusID,Description,SortOrder
FROM MMS.dbo.ValMemberCardStatus WITH(NoLock)

