
CREATE VIEW dbo.vValMemberCardCode AS 
SELECT ValMemberCardCodeID,Description,SortOrder
FROM MMS.dbo.ValMemberCardCode WITH(NoLock)

