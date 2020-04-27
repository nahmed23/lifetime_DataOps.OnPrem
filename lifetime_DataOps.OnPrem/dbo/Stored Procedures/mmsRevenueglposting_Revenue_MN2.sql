


--
-- Returns a set of tran records for the Revenueglposting report
-- 
-- Parameters: Transaction Types include Adjustment, Charge, Refund and 
--             Clubs included in this report are - MNEA, MNHP, MNMN,MNNH and MNCN
----           also, the transactions are only coming from closed drawers.

CREATE    PROC dbo.mmsRevenueglposting_Revenue_MN2
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

EXEC mmsRevenueglposting_Revenue_Generic '2,5,11,141,151,166,'

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END



