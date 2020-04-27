
CREATE VIEW dbo.vValContactType AS 
SELECT ValContactTypeID,Description,SortOrder
FROM MMS.dbo.ValContactType WITH (NoLock)

