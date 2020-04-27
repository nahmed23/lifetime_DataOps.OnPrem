


CREATE PROCEDURE [dbo].[procCognos_ChildCenter_OccupancySummary] (
  @ParamStartDateTime datetime,
  @ParamEndDateTime datetime,
  @ParamClubIDList VARCHAR(8000)
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

DECLARE @ReportRunDateTime VARCHAR(21)
SET @ReportRunDateTime = Replace(Substring(convert(varchar,getdate(),100),1,6)+', '+Substring(convert(varchar,getdate(),100),8,10)+' '+Substring(convert(varchar,getdate(),100),18,2),'  ',' ')

--Define a variable for Today, Remove time portions of the Start and End Dates
--Add 1 day to End Date to make sure EndDate is included
DECLARE @Today DATETIME
DECLARE @UTCToday DATETIME
DECLARE @UpdatedEndDate DATETIME
DECLARE @DateRange INT

SELECT @Today = CONVERT(DATETIME,CONVERT(VARCHAR(10),GETDATE(),101),101),
       @UTCToday = CONVERT(DATETIME,CONVERT(VARCHAR(10),GETUTCDATE(),101),101),
       @ParamStartDateTime = (CASE WHEN @ParamStartDateTime = '1/1/1900'
	                                  THEN CONVERT(DATETIME,CONVERT(VARCHAR(10),GETDATE()-1,101),101)
									  ELSE CONVERT(DATETIME,CONVERT(VARCHAR(10),@ParamStartDateTime,101),101)
									  END),
	   @ParamEndDateTime = (CASE WHEN @ParamEndDateTime = '1/1/1900'
	                                  THEN CONVERT(DATETIME,CONVERT(VARCHAR(10),GETDATE()-1,101),101)
									  ELSE CONVERT(DATETIME,CONVERT(VARCHAR(10),@ParamEndDateTime,101),101)
									  END),
       @UpdatedEndDate = CONVERT(DATETIME,CONVERT(VARCHAR(10),DATEADD(DD,1,@ParamEndDateTime),101),101)

SET @DateRange = DATEDIFF(DD,@ParamStartDateTime, @UpdatedEndDate)

CREATE TABLE #tmpList (StringField VARCHAR(50))

-- Parse the ClubIDs into a temp table
EXEC procParseIntegerList @ParamClubIDList
CREATE TABLE #Clubs (ClubID INT)
INSERT INTO #Clubs (ClubID) SELECT StringField FROM #tmpList

--Set the interval for the snapshots
DECLARE @MinuteFactor INT
SET @MinuteFactor = 15

CREATE TABLE #Times (Time DATETIME)

DECLARE @Time DATETIME
SET @Time = @ParamStartDateTime

--Establish all of the snapshot times 
WHILE @Time < @UpdatedEndDate
BEGIN
    INSERT INTO #Times (Time)
    VALUES(@Time)
    
    SET @Time = DATEADD(Minute,@MinuteFactor,@Time)
END

--Query #1
--Snapshot Averages
SELECT
	Region.Description RegionDescription,
	Club.ClubCode ClubCode,
	Club.ClubID MMSClubID,
	Club.ClubName ClubName,
	RIGHT('0' + CAST(DATEPART(Hour,Times.Time) AS VARCHAR(2)),2) + ':' + RIGHT('0' + CAST(DATEPART(Minute,Times.Time) AS VARCHAR(2)),2) SnapshotTime,
	COUNT(ChildCenterUsage.MemberID) / @DateRange AvgOccupancy_AllAges,
	SUM(CASE WHEN DATEDIFF(Month,0,ChildCenterUsage.CheckInDateTime - Member.DOB) < 12
				  AND 
				  DATEDIFF(Month,0,ChildCenterUsage.CheckInDateTime - Member.DOB) >= 3
			 THEN 1
			 ELSE 0
			 END) / @DateRange AvgOccupancy_Infant,
	SUM(CASE WHEN (DATEDIFF(Year,0,ChildCenterUsage.CheckInDateTime - Member.DOB) >= 1
				  AND 
				  DATEDIFF(Year,0,ChildCenterUsage.CheckInDateTime - Member.DOB) < 2)
				  OR
				  DATEDIFF(Month,0,ChildCenterUsage.CheckInDateTime - Member.DOB) < 3
			 THEN 1
			 ELSE 0
			 END) / @DateRange AvgOccupancy_1,
	SUM(CASE WHEN DATEDIFF(Year,0,ChildCenterUsage.CheckInDateTime - Member.DOB) >= 2
				  AND 
				  DATEDIFF(Year,0,ChildCenterUsage.CheckInDateTime - Member.DOB) < 3
			 THEN 1
			 ELSE 0
			 END) / @DateRange AvgOccupancy_2,
	SUM(CASE WHEN DATEDIFF(Year,0,ChildCenterUsage.CheckInDateTime - Member.DOB) >= 3
				  AND 
				  DATEDIFF(Year,0,ChildCenterUsage.CheckInDateTime - Member.DOB) < 4
			 THEN 1
			 ELSE 0
			 END) / @DateRange AvgOccupancy_3,
	SUM(CASE WHEN DATEDIFF(Year,0,ChildCenterUsage.CheckInDateTime - Member.DOB) >= 4
				  AND 
				  DATEDIFF(Year,0,ChildCenterUsage.CheckInDateTime - Member.DOB) < 5
			 THEN 1
			 ELSE 0
			 END) / @DateRange AvgOccupancy_4,
	SUM(CASE WHEN DATEDIFF(Year,0,ChildCenterUsage.CheckInDateTime - Member.DOB) >= 5
				  AND 
				  DATEDIFF(Year,0,ChildCenterUsage.CheckInDateTime - Member.DOB) < 6
			 THEN 1
			 ELSE 0
			 END) / @DateRange AvgOccupancy_5,
	SUM(CASE WHEN DATEDIFF(Year,0,ChildCenterUsage.CheckInDateTime - Member.DOB) >= 6
				  AND 
				  DATEDIFF(Year,0,ChildCenterUsage.CheckInDateTime - Member.DOB) < 7
			 THEN 1
			 ELSE 0
			 END) / @DateRange AvgOccupancy_6,
	SUM(CASE WHEN DATEDIFF(Year,0,ChildCenterUsage.CheckInDateTime - Member.DOB) >= 7
				  AND 
				  DATEDIFF(Year,0,ChildCenterUsage.CheckInDateTime - Member.DOB) < 8
			 THEN 1
			 ELSE 0
			 END) / @DateRange AvgOccupancy_7,
	SUM(CASE WHEN DATEDIFF(Year,0,ChildCenterUsage.CheckInDateTime - Member.DOB) >= 8
				  AND 
				  DATEDIFF(Year,0,ChildCenterUsage.CheckInDateTime - Member.DOB) < 9
			 THEN 1
			 ELSE 0
			 END) / @DateRange AvgOccupancy_8,
	SUM(CASE WHEN DATEDIFF(Year,0,ChildCenterUsage.CheckInDateTime - Member.DOB) >= 9
				  AND 
				  DATEDIFF(Year,0,ChildCenterUsage.CheckInDateTime - Member.DOB) < 10
			 THEN 1
			 ELSE 0
			 END) / @DateRange AvgOccupancy_9,
	SUM(CASE WHEN DATEDIFF(Year,0,ChildCenterUsage.CheckInDateTime - Member.DOB) >= 10
				  AND 
				  DATEDIFF(Year,0,ChildCenterUsage.CheckInDateTime - Member.DOB) < 11
			 THEN 1
			 ELSE 0
			 END) / @DateRange AvgOccupancy_10,
	SUM(CASE WHEN DATEDIFF(Year,0,ChildCenterUsage.CheckInDateTime - Member.DOB) >= 11
			 THEN 1
			 ELSE 0
			 END) / @DateRange AvgOccupancy_11,
	0 TotalCheckins_AllAges,
	0 TotalCheckins_Infant,
	0 TotalCheckins_1,
	0 TotalCheckins_2,
	0 TotalCheckins_3,
	0 TotalCheckins_4,
	0 TotalCheckins_5,
	0 TotalCheckins_6,
	0 TotalCheckins_7,
	0 TotalCheckins_8,
	0 TotalCheckins_9,
	0 TotalCheckins_10,
	0 TotalCheckins_11
  INTO #Results
FROM vChildCenterUsage ChildCenterUsage
JOIN #Clubs Clubs
  ON Clubs.ClubID = ChildCenterUsage.ClubID
JOIN vClub Club
  ON Club.ClubID = Clubs.ClubID
JOIN vValTimeZone TimeZone
  ON TimeZone.ValTimeZoneID = Club.ValTimeZoneID
JOIN #Times Times
  ON Times.Time > ChildCenterUsage.CheckInDateTime
 AND Times.Time <= ISNULL(ChildCenterUsage.CheckOutDateTime,
				CASE WHEN CONVERT(DATETIME,CONVERT(VARCHAR(10),ChildCenterUsage.UTCCheckInDateTime,101),101) = @UTCToday
					  AND ChildCenterUsage.CheckInDateTimeZone LIKE '%ST'
					 THEN DATEADD(Hour,-1 * TimeZone.STOffset,GETUTCDATE())
					 WHEN CONVERT(DATETIME,CONVERT(VARCHAR(10),ChildCenterUsage.UTCCheckInDateTime,101),101) = @UTCToday
					  AND ChildCenterUsage.CheckInDateTimeZone LIKE '%DT'
					 THEN DATEADD(Hour,-1 * TimeZone.DSTOffset,GETUTCDATE())
					 ELSE DATEADD(Minute, -1,CONVERT(DATETIME,CONVERT(VARCHAR(10),DATEADD(DD,1,ChildCenterUsage.CheckInDateTime),101),101))
				 END) 
JOIN vValRegion Region
  ON Region.ValRegionID = Club.ValRegionID
JOIN vMember Member
  ON Member.MemberID = ChildCenterUsage.MemberID
GROUP BY 
	Region.Description,
	Club.ClubCode,
	Club.ClubID,
	Club.ClubName,
	RIGHT('0' + CAST(DATEPART(Hour,Times.Time) AS VARCHAR(2)),2) + ':' + RIGHT('0' + CAST(DATEPART(Minute,Times.Time) AS VARCHAR(2)),2)

UNION ALL


--Query #2 - Total Check-Ins
--If there is no Total Data, a Row of Zeros is returned
SELECT
	Region.Description RegionDescription,
	Club.ClubCode ClubCode,
	Club.ClubID MMSClubID,
	Club.ClubName ClubName,
	'24:00' SnapshotTime,
	0 AvgOccupancy_AllAges,
	0 AvgOccupancy_Infant,
	0 AvgOccupancy_1,
	0 AvgOccupancy_2,
	0 AvgOccupancy_3,
	0 AvgOccupancy_4,
	0 AvgOccupancy_5,
	0 AvgOccupancy_6,
	0 AvgOccupancy_7,
	0 AvgOccupancy_8,
	0 AvgOccupancy_9,
	0 AvgOccupancy_10,
	0 AvgOccupancy_11,
	COUNT(ChildCenterUsage.MemberID) TotalCheckins_AllAges,
	SUM(CASE WHEN DATEDIFF(Month,0,ChildCenterUsage.CheckInDateTime - Member.DOB) < 12
				  AND 
				  DATEDIFF(Month,0,ChildCenterUsage.CheckInDateTime - Member.DOB) >= 3
			 THEN 1
			 ELSE 0
			 END) TotalCheckins_Infant,
	SUM(CASE WHEN (DATEDIFF(Year,0,ChildCenterUsage.CheckInDateTime - Member.DOB) >= 1
				  AND 
				  DATEDIFF(Year,0,ChildCenterUsage.CheckInDateTime - Member.DOB) < 2)
				  OR
				  DATEDIFF(Month,0,ChildCenterUsage.CheckInDateTime - Member.DOB) < 3
			 THEN 1
			 ELSE 0
			 END) TotalCheckins_1,
	SUM(CASE WHEN DATEDIFF(Year,0,ChildCenterUsage.CheckInDateTime - Member.DOB) >= 2
				  AND 
				  DATEDIFF(Year,0,ChildCenterUsage.CheckInDateTime - Member.DOB) < 3
			 THEN 1
			 ELSE 0
			 END) TotalCheckins_2,
	SUM(CASE WHEN DATEDIFF(Year,0,ChildCenterUsage.CheckInDateTime - Member.DOB) >= 3
				  AND 
				  DATEDIFF(Year,0,ChildCenterUsage.CheckInDateTime - Member.DOB) < 4
			 THEN 1
			 ELSE 0
			 END) TotalCheckins_3,
	SUM(CASE WHEN DATEDIFF(Year,0,ChildCenterUsage.CheckInDateTime - Member.DOB) >= 4
				  AND 
				  DATEDIFF(Year,0,ChildCenterUsage.CheckInDateTime - Member.DOB) < 5
			 THEN 1
			 ELSE 0
			 END) TotalCheckins_4,
	SUM(CASE WHEN DATEDIFF(Year,0,ChildCenterUsage.CheckInDateTime - Member.DOB) >= 5
				  AND 
				  DATEDIFF(Year,0,ChildCenterUsage.CheckInDateTime - Member.DOB) < 6
			 THEN 1
			 ELSE 0
			 END) TotalCheckins_5,
	SUM(CASE WHEN DATEDIFF(Year,0,ChildCenterUsage.CheckInDateTime - Member.DOB) >= 6
				  AND 
				  DATEDIFF(Year,0,ChildCenterUsage.CheckInDateTime - Member.DOB) < 7
			 THEN 1
			 ELSE 0
			 END) TotalCheckins_6,
	SUM(CASE WHEN DATEDIFF(Year,0,ChildCenterUsage.CheckInDateTime - Member.DOB) >= 7
				  AND 
				  DATEDIFF(Year,0,ChildCenterUsage.CheckInDateTime - Member.DOB) < 8
			 THEN 1
			 ELSE 0
			 END) TotalCheckins_7,
	SUM(CASE WHEN DATEDIFF(Year,0,ChildCenterUsage.CheckInDateTime - Member.DOB) >= 8
				  AND 
				  DATEDIFF(Year,0,ChildCenterUsage.CheckInDateTime - Member.DOB) < 9
			 THEN 1
			 ELSE 0
			 END) TotalCheckins_8,
	SUM(CASE WHEN DATEDIFF(Year,0,ChildCenterUsage.CheckInDateTime - Member.DOB) >= 9
				  AND 
				  DATEDIFF(Year,0,ChildCenterUsage.CheckInDateTime - Member.DOB) < 10
			 THEN 1
			 ELSE 0
			 END) TotalCheckins_9,
	SUM(CASE WHEN DATEDIFF(Year,0,ChildCenterUsage.CheckInDateTime - Member.DOB) >= 10
				  AND 
				  DATEDIFF(Year,0,ChildCenterUsage.CheckInDateTime - Member.DOB) < 11
			 THEN 1
			 ELSE 0
			 END) TotalCheckins_10,
	SUM(CASE WHEN DATEDIFF(Year,0,ChildCenterUsage.CheckInDateTime - Member.DOB) >= 11
			 THEN 1
			 ELSE 0
			 END) TotalCheckins_11
FROM #Clubs Clubs
JOIN vClub Club
  ON Club.ClubID = Clubs.ClubID
JOIN vValRegion Region
  ON Region.ValRegionID = Club.ValRegionID
JOIN vValTimeZone TimeZone
  ON TimeZone.ValTimeZoneID = Club.ValTimeZoneID
JOIN vChildCenterUsage ChildCenterUsage
  ON Clubs.ClubID = ChildCenterUsage.ClubID
 AND ChildCenterUsage.CheckInDateTime >= @ParamStartDateTime
  AND ISNULL(ChildCenterUsage.CheckOutDateTime,
				CASE WHEN CONVERT(DATETIME,CONVERT(VARCHAR(10),ChildCenterUsage.UTCCheckInDateTime,101),101) = @UTCToday
					  AND ChildCenterUsage.CheckInDateTimeZone LIKE '%ST'
					 THEN DATEADD(Hour,-1 * TimeZone.STOffset,GETUTCDATE())
					 WHEN CONVERT(DATETIME,CONVERT(VARCHAR(10),ChildCenterUsage.UTCCheckInDateTime,101),101) = @UTCToday
					  AND ChildCenterUsage.CheckInDateTimeZone LIKE '%DT'
					 THEN DATEADD(Hour,-1 * TimeZone.DSTOffset,GETUTCDATE())
					 ELSE DATEADD(Minute, -1,CONVERT(DATETIME,CONVERT(VARCHAR(10),DATEADD(DD,1,ChildCenterUsage.CheckInDateTime),101),101))
				 END) < @UpdatedEndDate
JOIN vMember Member
  ON Member.MemberID = ChildCenterUsage.MemberID
GROUP BY 
	Region.Description,
	Club.ClubCode,
	Club.ClubID,
	Club.ClubName

SELECT RegionDescription,
       ClubCode,
       MMSClubID,
       ClubName,
       @ParamStartDateTime ReportStartDate,
       @ParamEndDateTime ReportEndDate,
       CASE WHEN @ParamStartDateTime <= @Today AND @ParamEndDateTime >= @Today
                 THEN 'This report may include snapshot times for an incomplete day.'
            ELSE '' END SubheaderNoticeText,
       SnapshotTime,
       AvgOccupancy_AllAges,
       AvgOccupancy_Infant,
       AvgOccupancy_1,
       AvgOccupancy_2,
       AvgOccupancy_3,
       AvgOccupancy_4,
       AvgOccupancy_5,
       AvgOccupancy_6,
       AvgOccupancy_7,
       AvgOccupancy_8,
       AvgOccupancy_9,
       AvgOccupancy_10,
       AvgOccupancy_11,
       TotalCheckins_AllAges,
       TotalCheckins_Infant,
       TotalCheckins_1,
       TotalCheckins_2,
       TotalCheckins_3,
       TotalCheckins_4,
       TotalCheckins_5,
       TotalCheckins_6,
       TotalCheckins_7,
       TotalCheckins_8,
       TotalCheckins_9,
       TotalCheckins_10,
       TotalCheckins_11,
       Replace(Substring(convert(varchar,@ParamStartDateTime,100),1,6)+', '+Substring(convert(varchar,@ParamStartDateTime,100),8,4),'  ',' ') + ' through ' + Replace(Substring(convert(varchar,@ParamEndDateTime,100),1,6)+', '+Substring(convert(varchar,@ParamEndDateTime,100),8,4),'  ',' ') HeaderDateRange,
       @ReportRunDateTime ReportRunDateTime,
       CAST(NULL AS VARCHAR(70)) HeaderEmptyResultSet
  FROM #Results
 WHERE (SELECT COUNT(*) FROM #Results) > 0
UNION ALL
SELECT CAST(NULL AS VARCHAR(50)) RegionDescription,
       CAST(NULL AS VARCHAR(3)) ClubCode,
       CAST(NULL AS INT) MMSClubID,
       CAST(NULL AS VARCHAR(50)) ClubName,
       @ParamStartDateTime ReportStartDate,
       @ParamEndDateTime ReportEndDate,
       CAST(NULL AS VARCHAR(61)) SubheaderNoticeText,
       CAST(NULL AS VARCHAR(5)) SnapshotTime,
       CAST(NULL AS INT) AvgOccupancy_AllAges,
       CAST(NULL AS INT) AvgOccupancy_Infant,
       CAST(NULL AS INT) AvgOccupancy_1,
       CAST(NULL AS INT) AvgOccupancy_2,
       CAST(NULL AS INT) AvgOccupancy_3,
       CAST(NULL AS INT) AvgOccupancy_4,
       CAST(NULL AS INT) AvgOccupancy_5,
       CAST(NULL AS INT) AvgOccupancy_6,
       CAST(NULL AS INT) AvgOccupancy_7,
       CAST(NULL AS INT) AvgOccupancy_8,
       CAST(NULL AS INT) AvgOccupancy_9,
       CAST(NULL AS INT) AvgOccupancy_10,
       CAST(NULL AS INT) AvgOccupancy_11,
       CAST(NULL AS INT) TotalCheckins_AllAges,
       CAST(NULL AS INT) TotalCheckins_Infant,
       CAST(NULL AS INT) TotalCheckins_1,
       CAST(NULL AS INT) TotalCheckins_2,
       CAST(NULL AS INT) TotalCheckins_3,
       CAST(NULL AS INT) TotalCheckins_4,
       CAST(NULL AS INT) TotalCheckins_5,
       CAST(NULL AS INT) TotalCheckins_6,
       CAST(NULL AS INT) TotalCheckins_7,
       CAST(NULL AS INT) TotalCheckins_8,
       CAST(NULL AS INT) TotalCheckins_9,
       CAST(NULL AS INT) TotalCheckins_10,
       CAST(NULL AS INT) TotalCheckins_11,
       Replace(Substring(convert(varchar,@ParamStartDateTime,100),1,6)+', '+Substring(convert(varchar,@ParamStartDateTime,100),8,4),'  ',' ') + ' through ' + Replace(Substring(convert(varchar,@ParamEndDateTime,100),1,6)+', '+Substring(convert(varchar,@ParamEndDateTime,100),8,4),'  ',' ') HeaderDateRange,
       @ReportRunDateTime ReportRunDateTime,
       'There is no data available for the selected parameters. Please re-try.' HeaderEmptyResultSet
 WHERE (SELECT COUNT(*) FROM #Results) = 0


DROP TABLE #tmpList
DROP TABLE #Clubs
DROP TABLE #Times
DROP TABLE #Results

END



