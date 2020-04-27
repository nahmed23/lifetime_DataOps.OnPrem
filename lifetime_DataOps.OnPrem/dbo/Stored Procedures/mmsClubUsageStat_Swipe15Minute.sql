



--
-- Returns Usage counts by region, by club and broken out by date
--
-- Parameters: a usage date range and a region
--
-- EXEC mmsClubUsageStat_Swipe15Minute '12|50|51|128', '7/1/06 12:00 AM', '7/6/06 11:59 PM'
--
CREATE                  PROC dbo.mmsClubUsageStat_Swipe15Minute (
  @ClubIDList VARCHAR(1000),
  @UsageStartDate SMALLDATETIME,
  @UsageEndDate SMALLDATETIME
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

CREATE TABLE #tmpList (StringField VARCHAR(15))
CREATE TABLE #Clubs (ClubID VARCHAR(15))
EXEC procParseStringList @ClubIDList
INSERT INTO #Clubs (ClubID) SELECT StringField FROM #tmpList
TRUNCATE TABLE #tmpList

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

	SELECT VR.Description RegionDescription, C.ClubID, C.ClubCode, C.ClubName,
		Count (MU.MemberUsageID) MemberUsageIDCount,
		UsageRange = Case 
			When DATEPART(Hour, MU.UsageDateTime) = 0 and DATEPART(Minute, MU.UsageDateTime) Between 0 and 15 Then '00:00 - 00:15'
			When DATEPART(Hour, MU.UsageDateTime) = 0 and DATEPART(Minute, MU.UsageDateTime) Between 16 and 30 Then '00:15 - 00:30'
			When DATEPART(Hour, MU.UsageDateTime) = 0 and DATEPART(Minute, MU.UsageDateTime) Between 31 and 45 Then '00:30 - 00:45'
			When DATEPART(Hour, MU.UsageDateTime) = 0 and DATEPART(Minute, MU.UsageDateTime) Between 46 and 60 Then '00:45 - 01:00'
			When DATEPART(Hour, MU.UsageDateTime) = 1 and DATEPART(Minute, MU.UsageDateTime) Between 0 and 15 Then '01:00 - 01:15'
			When DATEPART(Hour, MU.UsageDateTime) = 1 and DATEPART(Minute, MU.UsageDateTime) Between 16 and 30 Then '01:15 - 01:30'
			When DATEPART(Hour, MU.UsageDateTime) = 1 and DATEPART(Minute, MU.UsageDateTime) Between 31 and 45 Then '01:30 - 01:45'
			When DATEPART(Hour, MU.UsageDateTime) = 1 and DATEPART(Minute, MU.UsageDateTime) Between 46 and 60 Then '01:45 - 02:00'
			When DATEPART(Hour, MU.UsageDateTime) = 2 and DATEPART(Minute, MU.UsageDateTime) Between 0 and 15 Then '02:00 - 02:15'
			When DATEPART(Hour, MU.UsageDateTime) = 2 and DATEPART(Minute, MU.UsageDateTime) Between 16 and 30 Then '02:15 - 02:30'
			When DATEPART(Hour, MU.UsageDateTime) = 2 and DATEPART(Minute, MU.UsageDateTime) Between 31 and 45 Then '02:30 - 02:45'
			When DATEPART(Hour, MU.UsageDateTime) = 2 and DATEPART(Minute, MU.UsageDateTime) Between 46 and 60 Then '02:45 - 03:00'
			When DATEPART(Hour, MU.UsageDateTime) = 3 and DATEPART(Minute, MU.UsageDateTime) Between 0 and 15 Then '03:00 - 03:15'
			When DATEPART(Hour, MU.UsageDateTime) = 3 and DATEPART(Minute, MU.UsageDateTime) Between 16 and 30 Then '03:15 - 03:30'
			When DATEPART(Hour, MU.UsageDateTime) = 3 and DATEPART(Minute, MU.UsageDateTime) Between 31 and 45 Then '03:30 - 03:45'
			When DATEPART(Hour, MU.UsageDateTime) = 3 and DATEPART(Minute, MU.UsageDateTime) Between 46 and 60 Then '03:45 - 04:00'
			When DATEPART(Hour, MU.UsageDateTime) = 4 and DATEPART(Minute, MU.UsageDateTime) Between 0 and 15 Then '04:00 - 04:15'
			When DATEPART(Hour, MU.UsageDateTime) = 4 and DATEPART(Minute, MU.UsageDateTime) Between 16 and 30 Then '04:15 - 04:30'
			When DATEPART(Hour, MU.UsageDateTime) = 4 and DATEPART(Minute, MU.UsageDateTime) Between 31 and 45 Then '04:30 - 04:45'
			When DATEPART(Hour, MU.UsageDateTime) = 4 and DATEPART(Minute, MU.UsageDateTime) Between 46 and 60 Then '04:45 - 05:00'
			When DATEPART(Hour, MU.UsageDateTime) = 5 and DATEPART(Minute, MU.UsageDateTime) Between 0 and 15 Then '05:00 - 05:15'
			When DATEPART(Hour, MU.UsageDateTime) = 5 and DATEPART(Minute, MU.UsageDateTime) Between 16 and 30 Then '05:15 - 05:30'
			When DATEPART(Hour, MU.UsageDateTime) = 5 and DATEPART(Minute, MU.UsageDateTime) Between 31 and 45 Then '05:30 - 05:45'
			When DATEPART(Hour, MU.UsageDateTime) = 5 and DATEPART(Minute, MU.UsageDateTime) Between 46 and 60 Then '05:45 - 06:00'
			When DATEPART(Hour, MU.UsageDateTime) = 6 and DATEPART(Minute, MU.UsageDateTime) Between 0 and 15 Then '06:00 - 06:15'
			When DATEPART(Hour, MU.UsageDateTime) = 6 and DATEPART(Minute, MU.UsageDateTime) Between 16 and 30 Then '06:15 - 06:30'
			When DATEPART(Hour, MU.UsageDateTime) = 6 and DATEPART(Minute, MU.UsageDateTime) Between 31 and 45 Then '06:30 - 06:45'
			When DATEPART(Hour, MU.UsageDateTime) = 6 and DATEPART(Minute, MU.UsageDateTime) Between 46 and 60 Then '06:45 - 07:00'
			When DATEPART(Hour, MU.UsageDateTime) = 7 and DATEPART(Minute, MU.UsageDateTime) Between 0 and 15 Then '07:00 - 07:15'
			When DATEPART(Hour, MU.UsageDateTime) = 7 and DATEPART(Minute, MU.UsageDateTime) Between 16 and 30 Then '07:15 - 07:30'
			When DATEPART(Hour, MU.UsageDateTime) = 7 and DATEPART(Minute, MU.UsageDateTime) Between 31 and 45 Then '07:30 - 07:45'
			When DATEPART(Hour, MU.UsageDateTime) = 7 and DATEPART(Minute, MU.UsageDateTime) Between 46 and 60 Then '07:45 - 08:00'
			When DATEPART(Hour, MU.UsageDateTime) = 8 and DATEPART(Minute, MU.UsageDateTime) Between 0 and 15 Then '08:00 - 08:15'
			When DATEPART(Hour, MU.UsageDateTime) = 8 and DATEPART(Minute, MU.UsageDateTime) Between 16 and 30 Then '08:15 - 08:30'
			When DATEPART(Hour, MU.UsageDateTime) = 8 and DATEPART(Minute, MU.UsageDateTime) Between 31 and 45 Then '08:30 - 08:45'
			When DATEPART(Hour, MU.UsageDateTime) = 8 and DATEPART(Minute, MU.UsageDateTime) Between 46 and 60 Then '08:45 - 09:00'
			When DATEPART(Hour, MU.UsageDateTime) = 9 and DATEPART(Minute, MU.UsageDateTime) Between 0 and 15 Then '09:00 - 09:15'
			When DATEPART(Hour, MU.UsageDateTime) = 9 and DATEPART(Minute, MU.UsageDateTime) Between 16 and 30 Then '09:15 - 09:30'
			When DATEPART(Hour, MU.UsageDateTime) = 9 and DATEPART(Minute, MU.UsageDateTime) Between 31 and 45 Then '09:30 - 09:45'
			When DATEPART(Hour, MU.UsageDateTime) = 9 and DATEPART(Minute, MU.UsageDateTime) Between 46 and 60 Then '09:45 - 10:00'
			When DATEPART(Hour, MU.UsageDateTime) = 10 and DATEPART(Minute, MU.UsageDateTime) Between 0 and 15 Then '10:00 - 10:15'
			When DATEPART(Hour, MU.UsageDateTime) = 10 and DATEPART(Minute, MU.UsageDateTime) Between 16 and 30 Then '10:15 - 10:30'
			When DATEPART(Hour, MU.UsageDateTime) = 10 and DATEPART(Minute, MU.UsageDateTime) Between 31 and 45 Then '10:30 - 10:45'
			When DATEPART(Hour, MU.UsageDateTime) = 10 and DATEPART(Minute, MU.UsageDateTime) Between 46 and 60 Then '10:45 - 11:00'
			When DATEPART(Hour, MU.UsageDateTime) = 11 and DATEPART(Minute, MU.UsageDateTime) Between 0 and 15 Then '11:00 - 11:15'
			When DATEPART(Hour, MU.UsageDateTime) = 11 and DATEPART(Minute, MU.UsageDateTime) Between 16 and 30 Then '11:15 - 11:30'
			When DATEPART(Hour, MU.UsageDateTime) = 11 and DATEPART(Minute, MU.UsageDateTime) Between 16 and 45 Then '11:30 - 11:45'
			When DATEPART(Hour, MU.UsageDateTime) = 11 and DATEPART(Minute, MU.UsageDateTime) Between 46 and 60 Then '11:45 - 12:00'
			When DATEPART(Hour, MU.UsageDateTime) = 12 and DATEPART(Minute, MU.UsageDateTime) Between 0 and 15 Then '12:00 - 12:15'
			When DATEPART(Hour, MU.UsageDateTime) = 12 and DATEPART(Minute, MU.UsageDateTime) Between 16 and 30 Then '12:15 - 12:30'
			When DATEPART(Hour, MU.UsageDateTime) = 12 and DATEPART(Minute, MU.UsageDateTime) Between 31 and 45 Then '12:30 - 12:45'
			When DATEPART(Hour, MU.UsageDateTime) = 12 and DATEPART(Minute, MU.UsageDateTime) Between 46 and 60 Then '12:45 - 13:00'
			When DATEPART(Hour, MU.UsageDateTime) = 13 and DATEPART(Minute, MU.UsageDateTime) Between 0 and 15 Then '13:00 - 13:15'
			When DATEPART(Hour, MU.UsageDateTime) = 13 and DATEPART(Minute, MU.UsageDateTime) Between 16 and 30 Then '13:15 - 13:30'
			When DATEPART(Hour, MU.UsageDateTime) = 13 and DATEPART(Minute, MU.UsageDateTime) Between 31 and 45 Then '13:30 - 13:45'
			When DATEPART(Hour, MU.UsageDateTime) = 13 and DATEPART(Minute, MU.UsageDateTime) Between 46 and 60 Then '13:45 - 14:00'
			When DATEPART(Hour, MU.UsageDateTime) = 14 and DATEPART(Minute, MU.UsageDateTime) Between 0 and 15 Then '14:00 - 14:15'
			When DATEPART(Hour, MU.UsageDateTime) = 14 and DATEPART(Minute, MU.UsageDateTime) Between 16 and 30 Then '14:15 - 14:30'
			When DATEPART(Hour, MU.UsageDateTime) = 14 and DATEPART(Minute, MU.UsageDateTime) Between 31 and 45 Then '14:30 - 14:45'
			When DATEPART(Hour, MU.UsageDateTime) = 14 and DATEPART(Minute, MU.UsageDateTime) Between 46 and 60 Then '14:45 - 15:00'
			When DATEPART(Hour, MU.UsageDateTime) = 15 and DATEPART(Minute, MU.UsageDateTime) Between 0 and 15 Then '15:00 - 15:15'
			When DATEPART(Hour, MU.UsageDateTime) = 15 and DATEPART(Minute, MU.UsageDateTime) Between 16 and 30 Then '15:15 - 15:30'
			When DATEPART(Hour, MU.UsageDateTime) = 15 and DATEPART(Minute, MU.UsageDateTime) Between 31 and 45 Then '15:30 - 15:45'
			When DATEPART(Hour, MU.UsageDateTime) = 15 and DATEPART(Minute, MU.UsageDateTime) Between 46 and 60 Then '15:45 - 16:00'
			When DATEPART(Hour, MU.UsageDateTime) = 16 and DATEPART(Minute, MU.UsageDateTime) Between 0 and 15 Then '16:00 - 16:15'
			When DATEPART(Hour, MU.UsageDateTime) = 16 and DATEPART(Minute, MU.UsageDateTime) Between 16 and 30 Then '16:15 - 16:30'
			When DATEPART(Hour, MU.UsageDateTime) = 16 and DATEPART(Minute, MU.UsageDateTime) Between 31 and 45 Then '16:30 - 16:45'
			When DATEPART(Hour, MU.UsageDateTime) = 16 and DATEPART(Minute, MU.UsageDateTime) Between 46 and 60 Then '16:45 - 17:00'
			When DATEPART(Hour, MU.UsageDateTime) = 17 and DATEPART(Minute, MU.UsageDateTime) Between 0 and 15 Then '17:00 - 17:15'
			When DATEPART(Hour, MU.UsageDateTime) = 17 and DATEPART(Minute, MU.UsageDateTime) Between 16 and 30 Then '17:15 - 17:30'
			When DATEPART(Hour, MU.UsageDateTime) = 17 and DATEPART(Minute, MU.UsageDateTime) Between 31 and 45 Then '17:30 - 17:45'
			When DATEPART(Hour, MU.UsageDateTime) = 17 and DATEPART(Minute, MU.UsageDateTime) Between 46 and 60 Then '17:45 - 18:00'
			When DATEPART(Hour, MU.UsageDateTime) = 18 and DATEPART(Minute, MU.UsageDateTime) Between 0 and 15 Then '18:00 - 18:15'
			When DATEPART(Hour, MU.UsageDateTime) = 18 and DATEPART(Minute, MU.UsageDateTime) Between 16 and 30 Then '18:15 - 18:30'
			When DATEPART(Hour, MU.UsageDateTime) = 18 and DATEPART(Minute, MU.UsageDateTime) Between 31 and 45 Then '18:30 - 18:45'
			When DATEPART(Hour, MU.UsageDateTime) = 18 and DATEPART(Minute, MU.UsageDateTime) Between 46 and 60 Then '18:45 - 19:00'
			When DATEPART(Hour, MU.UsageDateTime) = 19 and DATEPART(Minute, MU.UsageDateTime) Between 0 and 15 Then '19:00 - 19:15'
			When DATEPART(Hour, MU.UsageDateTime) = 19 and DATEPART(Minute, MU.UsageDateTime) Between 16 and 30 Then '19:15 - 19:30'
			When DATEPART(Hour, MU.UsageDateTime) = 19 and DATEPART(Minute, MU.UsageDateTime) Between 31 and 45 Then '19:30 - 19:45'
			When DATEPART(Hour, MU.UsageDateTime) = 19 and DATEPART(Minute, MU.UsageDateTime) Between 46 and 60 Then '19:45 - 20:00'
			When DATEPART(Hour, MU.UsageDateTime) = 20 and DATEPART(Minute, MU.UsageDateTime) Between 0 and 15 Then '20:00 - 20:15'
			When DATEPART(Hour, MU.UsageDateTime) = 20 and DATEPART(Minute, MU.UsageDateTime) Between 16 and 30 Then '20:15 - 20:30'
			When DATEPART(Hour, MU.UsageDateTime) = 20 and DATEPART(Minute, MU.UsageDateTime) Between 31 and 45 Then '20:30 - 20:45'
			When DATEPART(Hour, MU.UsageDateTime) = 20 and DATEPART(Minute, MU.UsageDateTime) Between 46 and 60 Then '20:45 - 21:00'
			When DATEPART(Hour, MU.UsageDateTime) = 21 and DATEPART(Minute, MU.UsageDateTime) Between 0 and 15 Then '21:00 - 21:15'
			When DATEPART(Hour, MU.UsageDateTime) = 21 and DATEPART(Minute, MU.UsageDateTime) Between 16 and 30 Then '21:15 - 21:30'
			When DATEPART(Hour, MU.UsageDateTime) = 21 and DATEPART(Minute, MU.UsageDateTime) Between 31 and 45 Then '21:30 - 21:45'
			When DATEPART(Hour, MU.UsageDateTime) = 21 and DATEPART(Minute, MU.UsageDateTime) Between 46 and 60 Then '21:45 - 22:00'
			When DATEPART(Hour, MU.UsageDateTime) = 22 and DATEPART(Minute, MU.UsageDateTime) Between 0 and 15 Then '22:00 - 22:15'
			When DATEPART(Hour, MU.UsageDateTime) = 22 and DATEPART(Minute, MU.UsageDateTime) Between 16 and 30 Then '22:15 - 22:30'
			When DATEPART(Hour, MU.UsageDateTime) = 22 and DATEPART(Minute, MU.UsageDateTime) Between 31 and 45 Then '22:30 - 22:45'
			When DATEPART(Hour, MU.UsageDateTime) = 22 and DATEPART(Minute, MU.UsageDateTime) Between 46 and 60 Then '22:45 - 23:00'
			When DATEPART(Hour, MU.UsageDateTime) = 23 and DATEPART(Minute, MU.UsageDateTime) Between 0 and 15 Then '23:00 - 23:15'
			When DATEPART(Hour, MU.UsageDateTime) = 23 and DATEPART(Minute, MU.UsageDateTime) Between 16 and 30 Then '23:15 - 23:30'
			When DATEPART(Hour, MU.UsageDateTime) = 23 and DATEPART(Minute, MU.UsageDateTime) Between 31 and 45 Then '23:30 - 23:45'
			When DATEPART(Hour, MU.UsageDateTime) = 23 and DATEPART(Minute, MU.UsageDateTime) Between 46 and 60 Then '23:45 - 24:00'
		End,
		MU.UsageDateTime,
		DATEPART(Hour, MU.UsageDateTime) as UsageHour,
		DATEPART(Minute, MU.UsageDateTime) as UsageMinute,
		CONVERT(DATETIME, CONVERT(VARCHAR, MU.UsageDateTime, 102), 102) as UsageDate,
		DATENAME(WEEKDAY, MU.UsageDateTime) as UsageDayofWeek, DATENAME(MONTH, MU.UsageDateTime) as UsageMonth,
		DATENAME(YEAR, MU.UsageDateTime) as UsageYear
	  FROM dbo.vMemberUsage MU
	  JOIN dbo.vClub C
	       ON MU.ClubID = C.ClubID
	  JOIN #Clubs CS
	       ON C.ClubID = CS.ClubID AND C.DisplayUIFlag = 1
	  JOIN dbo.vValRegion VR
	       ON C.ValRegionID = VR.ValRegionID
	  JOIN dbo.vMember M
	       ON MU.MemberID = M.MemberID
	WHERE MU.UsageDateTime BETWEEN @UsageStartDate AND @UsageEndDate
	GROUP BY VR.Description, C.ClubID, C.ClubCode, C.ClubName,
		MU.UsageDateTime,
		CONVERT(DATETIME, CONVERT(VARCHAR, MU.UsageDateTime, 102), 102),
		DATENAME(WEEKDAY, MU.UsageDateTime), DATENAME(MONTH, MU.UsageDateTime),
		DATENAME(YEAR, MU.UsageDateTime)
	ORDER BY VR.Description, C.ClubName, CONVERT(DATETIME, CONVERT(VARCHAR, MU.UsageDateTime, 102), 102), DATEPART(HOUR, MU.UsageDateTime)

DROP TABLE #Clubs
DROP TABLE #tmpList

-- Report Logging
UPDATE HyperionReportLog
SET EndDateTime = getdate()
WHERE ReportLogID = @Identity

END




