


--
-- Returns a set of tran records for the Revenueglposting report
-- 
-- Parameters: Transaction Types include Adjustment, Charge, Refund and 
--             Clubs included in this report are - MNMG, MNPL, MNRV, MNSV, 
--             MNSP, and MNWB
----           also, the transactions are only coming from closed drawers.

CREATE   PROC dbo.mmsRevenueglposting_Revenue_MN3
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

eXEC mmsRevenueglposting_Revenue_Generic '3,4,8,9,133,167,'

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END


