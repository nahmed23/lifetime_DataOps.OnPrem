
CREATE VIEW dbo.vValMemberCardType AS 
SELECT ValMemberCardTypeID,Description,SortOrder
FROM MMS.dbo.ValMemberCardType WITH(NoLock)

