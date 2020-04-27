

CREATE    PROC [dbo].[mmsMemberStatusSummary_Scheduled_IN_OH_MD_NC_VA]

AS
BEGIN 
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

EXEC mmsMemberstatussummary_Scheduled 'East-MidAtlantic|East-OhioIN|East-Central|East-Undefined'

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END
