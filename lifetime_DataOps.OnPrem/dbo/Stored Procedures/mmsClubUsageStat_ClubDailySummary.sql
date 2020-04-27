



--
-- Returns Usage counts by club and broken out by date
--
-- Parameters: a usage date range and a bar separated list of clubnames
--
-- EXEC mmsClubUsageStat_ClubDailySummary 'Apple Valley, MN|Bloomington, MN|Chanhassen, MN|Minneapolis Athletic Club|Plymouth, MN|Savage, MN', '5/1/06 12:00 AM', '5/15/06 11:59 PM'
--
CREATE              PROC dbo.mmsClubUsageStat_ClubDailySummary (
  @ClubIDList VARCHAR(2000),
  @UsageStartDate SMALLDATETIME,
  @UsageEndDate SMALLDATETIME
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
	Count (MU.MemberUsageID) MemberUsageIDCount, 
	CONVERT(DATETIME, CONVERT(VARCHAR, MU.UsageDateTime, 102), 102) as UsageDate,
	DATENAME(WEEKDAY, MU.UsageDateTime) as UsageDayofWeek, DATENAME(MONTH, MU.UsageDateTime) as UsageMonth,
	DATENAME(YEAR, MU.UsageDateTime) as UsageYear
  FROM dbo.vMemberUsage MU
  JOIN dbo.vClub C
       ON MU.ClubID = C.ClubID
  JOIN #Clubs CS
       ON C.ClubID = CS.ClubID AND C.DisplayUIFlag = 1
--  JOIN #Clubs CS
--       ON C.ClubName = CS.ClubName AND C.DisplayUIFlag = 1
  JOIN dbo.vValRegion VR
       ON C.ValRegionID = VR.ValRegionID
  JOIN dbo.vMember M
       ON MU.MemberID = M.MemberID
WHERE MU.UsageDateTime BETWEEN @UsageStartDate AND @UsageEndDate
 GROUP BY VR.Description, C.ClubID, C.ClubCode, C.ClubName, 
	CONVERT(DATETIME, CONVERT(VARCHAR, MU.UsageDateTime, 102), 102),
	DATENAME(WEEKDAY, MU.UsageDateTime), DATENAME(MONTH, MU.UsageDateTime),
	DATENAME(YEAR, MU.UsageDateTime)
 ORDER BY VR.Description, C.ClubName

DROP TABLE #Clubs
DROP TABLE #tmpList

-- Report Logging
UPDATE HyperionReportLog
SET EndDateTime = getdate()
WHERE ReportLogID = @Identity

END




