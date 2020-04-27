
CREATE    PROC [dbo].[mmsMemberStatusSummary_Scheduled_TX_NJ_NY_FL_GA]

AS
BEGIN 
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

EXEC mmsMemberstatussummary_Scheduled 'West-TXDallas|West-TXCentral|West-TXHouston|East-Northeast|East-Southeast'

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END
