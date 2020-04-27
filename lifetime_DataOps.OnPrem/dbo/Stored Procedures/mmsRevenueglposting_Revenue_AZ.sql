
--
-- Returns a set of tran records for the Revenue G.L.Posting report
-- 
-- Parameters: Transaction Types includes Sale, Adjustment, Charge, Refund, and 
--             all clubs in the Arizona region which includes the states of
---            Arizona, Utah and Colorado
----           also, the transactions are only coming from closed drawers.
---

CREATE    PROC [dbo].[mmsRevenueglposting_Revenue_AZ]
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

EXEC mmsRevenueglposting_Revenue_ByRegion '15|17'

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END
