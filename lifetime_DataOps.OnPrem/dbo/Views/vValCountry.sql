
CREATE VIEW dbo.vValCountry AS 
SELECT ValCountryID,Description,SortOrder,Abbreviation
FROM MMS.dbo.ValCountry WITH (NoLock)

