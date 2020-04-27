

CREATE VIEW dbo.vValBatchJobType AS 
SELECT ValBatchJobTypeID,Description,SortOrder,DisplayUIFlag
FROM MMS.dbo.ValBatchJobType WITH (NoLock)


