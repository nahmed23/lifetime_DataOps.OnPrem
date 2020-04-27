
CREATE   PROC [dbo].[mmsPackage_SessionsDetail_SessionsDelivered_scheduled]
AS
BEGIN

-- Report Logging
DECLARE @Identity AS INT
INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
SET @Identity = @@IDENTITY

  DECLARE @FirstOfCurrentMonth DATETIME
  DECLARE @SixteenthOfCurrentMonth DATETIME
  DECLARE @StartDate DATETIME
  DECLARE @EndDate DATETIME

  SET @FirstOfCurrentMonth  =  CONVERT(DATETIME, CONVERT(VARCHAR,month(getdate()))+'/01/'+ CONVERT(VARCHAR,year(getdate())),101)+' 12:00 AM'
  SET @SixteenthOfCurrentMonth =  CONVERT(DATETIME, CONVERT(VARCHAR,month(getdate()))+'/16/'+ CONVERT(VARCHAR,year(getdate())),101)+' 12:00 AM'
  
  -- run report for PP2 prior month data 
  -- 1st of month before 8 PM
  IF DAY(GETDATE()) = 1 and DATEPART( hh, GETDATE()) <= 20
	BEGIN
		SET @StartDate = DATEADD(mm, -1, @SixteenthOfCurrentMonth)
		SET @EndDate = DATEADD(ss, -1, @FirstOfCurrentMonth)
    END

  -- run report for PP1 current month data 
  -- 16th of month before 8 PM
  IF DAY(GETDATE()) = 16 and DATEPART( hh, GETDATE()) <= 20
	BEGIN
		SET @StartDate = @FirstOfCurrentMonth
		SET @EndDate = DATEADD(ss, -1, @SixteenthOfCurrentMonth)
    END
	
	-- Yoga, Mind Body, Personal Training, Nutrition Coaching
    EXEC mmsPackage_SessionsDetail 'All', @StartDate, @EndDate, '27|10|9|19', '< Do Not Limit By Partner Program >'

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END

