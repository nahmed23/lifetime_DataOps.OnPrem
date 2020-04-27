
CREATE VIEW dbo.vValActivityArea AS 
SELECT ValActivityAreaID,Description,SortOrder
FROM MMS.dbo.ValActivityArea WITH (NoLock)

