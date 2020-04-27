
CREATE VIEW dbo.vValMIPCategory AS 
SELECT ValMIPCategoryID,Description,SortOrder
FROM MMS.dbo.ValMIPCategory WITH (NoLock)

