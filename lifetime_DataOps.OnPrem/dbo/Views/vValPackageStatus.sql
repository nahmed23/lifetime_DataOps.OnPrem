

CREATE VIEW dbo.vValPackageStatus AS 
SELECT ValPackageStatusID,Description,SortOrder
FROM MMS.dbo.ValPackageStatus WITH (NoLock)


