

CREATE VIEW dbo.vValTimeZone AS 
SELECT ValTimeZoneID,Description,SortOrder,Abbreviation,DSTOffset,STOffset 
FROM MMS.dbo.ValTimeZone WITH (NoLock)


