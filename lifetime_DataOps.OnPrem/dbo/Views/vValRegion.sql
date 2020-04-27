
CREATE VIEW dbo.vValRegion AS 
SELECT ValRegionID,Description,SortOrder,CorporateIDList
FROM MMS.dbo.ValRegion WITH (NoLock)

