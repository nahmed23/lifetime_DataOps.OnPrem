

-- Procedure to get membership details for Non terminated memberships per club
--
-- Parameters: hard coded to the TX and VA regions for scheduled job

CREATE      PROC dbo.mmsMemDetail_Scheduled_TX_VA

AS
BEGIN

SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
DECLARE @Identity AS INT
INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
SET @Identity = @@IDENTITY

EXEC mmsMemDetail_Scheduled 'Texas|Virginia'

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END

