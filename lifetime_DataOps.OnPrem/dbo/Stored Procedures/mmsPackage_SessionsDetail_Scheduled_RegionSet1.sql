
/* 11 */
CREATE PROC [dbo].[mmsPackage_SessionsDetail_Scheduled_RegionSet1]
AS
BEGIN

-- Report Logging
DECLARE @Identity AS INT
INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
SET @Identity = @@IDENTITY

  DECLARE @FirstOfCurrentMonth DATETIME
  DECLARE @StartDate DATETIME
  DECLARE @EndDate DATETIME

  SET @FirstOfCurrentMonth  =  CONVERT(DATETIME, CONVERT(VARCHAR,month(getdate()))+'/01/'+ CONVERT(VARCHAR,year(getdate())),101)+' 12:00 AM'

  -- run report for MTD data
  SET @StartDate = @FirstOfCurrentMonth
  SET @EndDate = GETDATE()
 
  -- run report for prior month data 
  -- 1st of month before 8 PM
  IF DAY(GETDATE()) = 1 and DATEPART( hh, GETDATE()) <= 20
	BEGIN
		SET @StartDate = DATEADD(mm, -1, @FirstOfCurrentMonth)
		SET @EndDate = DATEADD(ss, -1, @FirstOfCurrentMonth)
    END
  
  -- build string of clubs
  DECLARE @ClubIDList VARCHAR(2000)
  DECLARE @CurrentClubID INT
  SET @ClubIDList = ''

  DECLARE clubids_cursor CURSOR FOR
  select C.ClubID from vClub C
    JOIN dbo.vValRegion VR
		   ON C.ValRegionID = VR.ValRegionID 
  where VR.ValRegionID in (23,26,27,28,29,35,36,37)

	OPEN clubids_cursor;

	FETCH NEXT FROM clubids_cursor
	INTO @CurrentClubID

	WHILE @@FETCH_STATUS = 0
	BEGIN
	  SET @ClubIDList = @ClubIDList+ cast(@CurrentClubID as varchar) + '|'
	  FETCH NEXT FROM clubids_cursor
	  INTO @CurrentClubID;
	END

	CLOSE clubids_cursor;
	DEALLOCATE clubids_cursor;

    EXEC mmsPackage_SessionsDetail @ClubIDList, @StartDate, @EndDate, 'ALL', '< Do Not Limit By Partner Program >'

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END
