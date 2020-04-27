






--
-- Returns a set of tran records for the Revenueglposting report
-- 
-- Parameters: Transaction Types include Adjustment, Charge, Refund and 
--             Clubs included in this report are - AZGB, AZTP,AZSC,AZPV,GAAL,
---            VACV, VAFF, MDCL, UTSV, NCCY and FLBR
----           also, the transactions are only coming from closed drawers.

CREATE      PROC dbo.mmsRevenueglposting_Revenue_AZVA
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

EXEC mmsRevenueglposting_Revenue_Generic '35,36,132,137,148,154,155,156,158,160,178,'

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END






