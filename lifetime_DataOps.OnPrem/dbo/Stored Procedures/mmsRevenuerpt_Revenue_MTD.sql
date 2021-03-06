﻿







--
-- Parameters include a date range and 'All' for All Clubs with a Department of Mind Body
--
-- This proc calculates yesterday's date, then from there, what the first day of that
-- Month is.
--

CREATE           PROC dbo.mmsRevenuerpt_Revenue_MTD
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

  DECLARE @Yesterday DATETIME
  DECLARE @FirstOfMonth DATETIME
  DECLARE @ToDay DATETIME

  SET @Yesterday  =  DATEADD(dd, -1, CONVERT(DATETIME, CONVERT(VARCHAR, GETDATE(), 102), 102))
  SET @FirstOfMonth  =  CONVERT(DATETIME, SUBSTRING(CONVERT(VARCHAR,@yesterday,112),1,6) + '01', 112)
  SET @ToDay  =  CONVERT(DATETIME, CONVERT(VARCHAR, GETDATE(), 102), 102)
--
--   SET @FirstOfMonth  =  '07/01/07'
--   SET @ToDay  =  '07/31/07'
--

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

  EXEC mmsRevenuerpt_Revenue @FirstofMonth, @ToDay,
	'All', 'Mind Body', 'All'

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END






