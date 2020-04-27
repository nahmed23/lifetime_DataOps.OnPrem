

-- Procedure to get membership details for Non terminated memberships per club
--
-- Parameters: hard coded to the MI region for scheduled job

CREATE      PROC dbo.mmsMemDetail_Scheduled_MI

AS
BEGIN

SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
DECLARE @Identity AS INT
INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
SET @Identity = @@IDENTITY

EXEC mmsMemDetail_Scheduled 'Michigan'

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END

