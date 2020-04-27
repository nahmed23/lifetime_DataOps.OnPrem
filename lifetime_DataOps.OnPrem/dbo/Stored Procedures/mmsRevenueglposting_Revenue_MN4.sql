


--
-- Returns a set of tran records for the Revenueglposting report
-- 
-- Parameters: Transaction Types include Adjustment, Charge, Refund and 
--             Clubs included in this report are - MNML, MNMT, MNAR, MNXT,
---            MNSL, MNED, MNNS and MNBV
----           also, the transactions are only coming from closed drawers.

CREATE      PROC dbo.mmsRevenueglposting_Revenue_MN4
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

EXEC mmsRevenueglposting_Revenue_Generic '170,171,172,173,174,175,176,177,'

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END






