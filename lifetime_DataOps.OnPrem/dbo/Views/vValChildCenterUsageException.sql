
CREATE VIEW dbo.vValChildCenterUsageException AS 
SELECT ValChildCenterUsageExceptionID,Description,SortOrder
FROM MMS.dbo.ValChildCenterUsageException WITH (NoLock)

