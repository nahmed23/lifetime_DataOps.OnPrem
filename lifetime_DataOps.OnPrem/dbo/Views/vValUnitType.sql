
CREATE VIEW dbo.vValUnitType AS 
SELECT ValUnitTypeID,Description,SortOrder
FROM MMS.dbo.ValUnitType WITH (NoLock)

