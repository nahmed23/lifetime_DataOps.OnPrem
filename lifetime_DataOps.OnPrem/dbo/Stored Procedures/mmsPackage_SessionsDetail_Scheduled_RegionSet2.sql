
CREATE PROC [dbo].[mmsPackage_SessionsDetail_Scheduled_RegionSet2]
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
SELECT @ClubIDList = STUFF((SELECT DISTINCT '|'+Convert(Varchar,C.ClubID)
                              FROM vValRegion VR
                              JOIN vClub C ON VR.ValRegionID = C.ValRegionID
                             WHERE VR.ValRegionID IN (19,20,15,17,32,33)
                               FOR XML PATH('')),1,1,'')

    EXEC mmsPackage_SessionsDetail @ClubIDList, @StartDate, @EndDate, 'ALL', '< Do Not Limit By Partner Program >'

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END
