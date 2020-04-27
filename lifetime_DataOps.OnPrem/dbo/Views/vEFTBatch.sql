

CREATE VIEW dbo.vEFTBatch
AS
SELECT     EFTBatchID, DrawerActivityID, StartTime, EndTime, LastUpdatedTime, ValEFTBatchStatusID, ManualStopFlag, ValEFTBatchJobID,Description,ErrorStopFlag,HardStopFlag
FROM         MMS.dbo.EFTBatch With (NOLOCK)


