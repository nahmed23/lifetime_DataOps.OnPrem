
CREATE       PROC mmsPT_DSSR_CommissionableSales_MTD_AllClubs
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

--
-- Parameters include a date range and 'All' for All Clubs with a | separated list of the Departments
--
-- This proc calculates yesterday's date, then from there, what the first day of that
-- Month is.
--
--  09-17-2010 MLL Updated to call mmsCommissionableSales using only "Merchandise"

  DECLARE @Yesterday DATETIME
  DECLARE @FirstOfMonth DATETIME
  DECLARE @ToDay DATETIME

  SET @Yesterday  =  DATEADD(dd, -1, CONVERT(DATETIME, CONVERT(VARCHAR, GETDATE(), 102), 102))
  SET @FirstOfMonth  =  CONVERT(DATETIME, SUBSTRING(CONVERT(VARCHAR,@yesterday,112),1,6) + '01', 112)
  SET @ToDay  =  CONVERT(DATETIME, CONVERT(VARCHAR, GETDATE(), 102), 102)

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

  EXEC mmsCommissionableSales @FirstofMonth, @ToDay,
	'All', 'Merchandise'


-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END
