CREATE VIEW dbo.vProgramNetworkType AS 
SELECT ProgramNetworkTypeID,Description,MaxSize,ProductID,GracePeriodDays,AdjustmentReasonCodeID,InsertedDateTime,UpdatedDateTime
FROM MMS.dbo.ProgramNetworkType WITH(NOLOCK)
