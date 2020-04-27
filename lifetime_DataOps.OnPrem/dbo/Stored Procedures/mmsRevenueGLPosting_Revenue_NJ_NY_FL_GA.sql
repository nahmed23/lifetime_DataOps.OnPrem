
CREATE PROC [dbo].[mmsRevenueGLPosting_Revenue_NJ_NY_FL_GA]
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

EXEC mmsRevenueglposting_Revenue_ByRegion '22|23' --East-Northeast|East-Southeast

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity


END
