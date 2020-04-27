


CREATE    PROC [dbo].[mmsRevenueglposting_Revenue_IL]
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
DECLARE @Identity AS INT
INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
SET @Identity = @@IDENTITY

EXEC mmsRevenueglposting_Revenue_ByRegion '20' --East-Midwest|Midwest

-- Report Logging
UPDATE HyperionReportLog
SET EndDateTime = getdate()
WHERE ReportLogID = @Identity


END
