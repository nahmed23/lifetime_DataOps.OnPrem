


--
-- Parameters include a date range and '0' for All Clubs 
--
-- This proc calculates yesterday's date, then from there, what the first day of that
-- Month is. Then executes another stored procedure using these parameters.
-- This returns data for MTD sessions delivered for all clubs.
--

CREATE        PROC dbo.mmsFitnessProgram_SessionsDelivered_MTD
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

  DECLARE @Yesterday DATETIME
  DECLARE @FirstOfMonth DATETIME

  SET @Yesterday  =  DATEADD(dd, -1, CONVERT(DATETIME, CONVERT(VARCHAR, GETDATE(), 102), 102))+ ' 11:59 PM'
  SET @FirstOfMonth  =  CONVERT(DATETIME, SUBSTRING(CONVERT(VARCHAR,@yesterday,112),1,6) + '01', 112)
  
-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

  EXEC mmsPackage_SessionsDetail 0,@FirstofMonth, @Yesterday

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END




