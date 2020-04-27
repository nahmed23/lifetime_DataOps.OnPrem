
CREATE VIEW dbo.vValCheckInGroup AS 
SELECT ValCheckInGroupID,Description,SortOrder
FROM MMS.dbo.ValCheckInGroup WITH (NoLock)

