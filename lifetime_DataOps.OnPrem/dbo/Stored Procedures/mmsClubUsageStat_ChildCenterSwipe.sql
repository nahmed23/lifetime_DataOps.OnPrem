


--
-- Returns Usage counts by region, by club and broken out by date
--
-- Parameters: a usage date range and a region
--
-- EXEC mmsClubUsageStat_ChildCenterSwipe '12|50|51|128', '3/1/07 12:00 AM', '3/26/07 11:59 PM'
--
CREATE                   PROC dbo.mmsClubUsageStat_ChildCenterSwipe (
  @ClubIDList VARCHAR(1000),
  @CheckInStartDate SMALLDATETIME,
  @CheckInEndDate SMALLDATETIME
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

CREATE TABLE #tmpList (StringField VARCHAR(15))
CREATE TABLE #Clubs (ClubID VARCHAR(15))
EXEC procParseStringList @ClubIDList
INSERT INTO #Clubs (ClubID) SELECT StringField FROM #tmpList
TRUNCATE TABLE #tmpList

SELECT VR.Description RegionDescription, C.ClubID, C.ClubCode, C.ClubName,
	Count (CCU.ChildCenterUsageID) ChildCenterUsageIDCount,
	ChildCenterCheckInRange = Case DATEPART(HOUR, CCU.CheckInDateTime)
		When 0 Then '00:00 - 01:00'
		When 1 Then '01:00 - 02:00'
		When 2 Then '02:00 - 03:00'
		When 3 Then '03:00 - 04:00'
		When 4 Then '04:00 - 05:00'
		When 5 Then '05:00 - 06:00'
		When 6 Then '06:00 - 07:00'
		When 7 Then '07:00 - 08:00'
		When 8 Then '08:00 - 09:00'
		When 9 Then '09:00 - 10:00'
		When 10 Then '10:00 - 11:00'
		When 11 Then '11:00 - 12:00'
		When 12 Then '12:00 - 13:00'
		When 13 Then '13:00 - 14:00'
		When 14 Then '14:00 - 15:00'
		When 15 Then '15:00 - 16:00'
		When 16 Then '16:00 - 17:00'
		When 17 Then '17:00 - 18:00'
		When 18 Then '18:00 - 19:00'
		When 19 Then '19:00 - 20:00'
		When 20 Then '20:00 - 21:00'
		When 21 Then '21:00 - 22:00'
		When 22 Then '22:00 - 23:00'
		When 23 Then '23:00 - 24:00'
	End,
	DATEPART(HOUR, CCU.CheckInDateTime) as CheckInHour,
	CONVERT(DATETIME, CONVERT(VARCHAR, CCU.CheckInDateTime, 102), 102) as CheckInDate,
	DATENAME(WEEKDAY, CCU.CheckInDateTime) as CheckInDayofWeek, DATENAME(MONTH, CCU.CheckInDateTime) as CheckInMonth,
	DATENAME(YEAR, CCU.CheckInDateTime) as CheckInYear
  FROM dbo.vChildCenterUsage CCU
  JOIN dbo.vClub C
       ON CCU.ClubID = C.ClubID
  JOIN #Clubs CS
       ON C.ClubID = CS.ClubID AND C.DisplayUIFlag = 1
  JOIN dbo.vValRegion VR
       ON C.ValRegionID = VR.ValRegionID
  JOIN dbo.vMember M
       ON CCU.MemberID = M.MemberID
WHERE CCU.CheckInDateTime BETWEEN @CheckInStartDate AND @CheckInEndDate
GROUP BY VR.Description, C.ClubID, C.ClubCode, C.ClubName, 
	DATEPART(HOUR, CCU.CheckInDateTime),
	CONVERT(DATETIME, CONVERT(VARCHAR, CCU.CheckInDateTime, 102), 102),
	DATENAME(WEEKDAY, CCU.CheckInDateTime), DATENAME(MONTH, CCU.CheckInDateTime),
	DATENAME(YEAR, CCU.CheckInDateTime)
ORDER BY VR.Description, C.ClubName, CONVERT(DATETIME, CONVERT(VARCHAR, CCU.CheckInDateTime, 102), 102), DATEPART(HOUR, CCU.CheckInDateTime)

DROP TABLE #Clubs
DROP TABLE #tmpList

-- Report Logging
UPDATE HyperionReportLog
SET EndDateTime = getdate()
WHERE ReportLogID = @Identity

END



