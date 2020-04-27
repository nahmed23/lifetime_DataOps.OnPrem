
CREATE    PROC [dbo].[mmsMemberStatusSummary_Scheduled_Canada]
AS
BEGIN 
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
DECLARE @Identity AS INT
INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
SET @Identity = @@IDENTITY

EXEC mmsMemberstatussummary_Scheduled 'Midwest'

-- Report Logging
UPDATE HyperionReportLog
SET EndDateTime = getdate()
WHERE ReportLogID = @Identity

END
