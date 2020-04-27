
CREATE VIEW dbo.vValCWRegion AS 
SELECT ValCWRegionID,Description,SortOrder
FROM MMS.dbo.ValCWRegion WITH (NoLock)

