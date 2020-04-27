






--
-- Returns a set of tran records for the Revenueglposting report
-- 
-- Parameters: Transaction Types include Adjustment, Charge, Refund and 
--             Clubs included in this report are - TXCV, TXFM, TXND, TXAU,
--             TXSA and KSOP
----           also, the transactions are only coming from closed drawers.

CREATE      PROC dbo.mmsRevenueglposting_Revenue_TX2
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

EXEC mmsRevenueglposting_Revenue_Generic '142,143,147,149,152,157,'

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END








