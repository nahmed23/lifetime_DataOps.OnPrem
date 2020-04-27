
CREATE VIEW dbo.vValEFTBatchJob AS 
SELECT ValEFTBatchJobID,Description,JobClass,SortOrder
FROM MMS.dbo.ValEFTBatchJob WITH (NoLock)

