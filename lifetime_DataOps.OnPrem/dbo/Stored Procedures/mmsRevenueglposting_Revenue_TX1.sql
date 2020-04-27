




--
-- Returns a set of tran records for the Revenueglposting report
-- 
-- Parameters: Transaction Types include Adjustment, Charge, Refund and 
--             Clubs included in this report are - TXPL, TXWB, TXSL, TXGL and TXCR
----           also, the transactions are only coming from closed drawers.

CREATE     PROC dbo.mmsRevenueglposting_Revenue_TX1
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

EXEC mmsRevenueglposting_Revenue_Generic '136,138,139,140,146,153,'

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END






