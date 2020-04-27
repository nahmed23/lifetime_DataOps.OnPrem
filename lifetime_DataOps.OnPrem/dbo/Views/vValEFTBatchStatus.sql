
CREATE VIEW dbo.vValEFTBatchStatus AS 
SELECT ValEFTBatchStatusID,Description,SortOrder
FROM MMS.dbo.ValEFTBatchStatus WITH (NoLock)

