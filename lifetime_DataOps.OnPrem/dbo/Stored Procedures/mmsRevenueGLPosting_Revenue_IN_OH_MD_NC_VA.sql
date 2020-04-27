


CREATE PROC [dbo].[mmsRevenueGLPosting_Revenue_IN_OH_MD_NC_VA]
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

EXEC mmsRevenueglposting_Revenue_ByRegion '25|24|30|31' --East-OhioIN|East-MidAtlantic|East-Central|East-Undefined

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity


END
