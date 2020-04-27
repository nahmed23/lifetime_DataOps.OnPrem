
CREATE VIEW dbo.vValDrawerStatus AS 
SELECT ValDrawerStatusID,Description,SortOrder
FROM MMS.dbo.ValDrawerStatus WITH (NoLock)

