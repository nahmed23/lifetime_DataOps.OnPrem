


--
-- Parameters include a date range and 'All' for All Clubs
--
-- This proc calculates yesterday's date, then from there, what the first day of that
-- Month is.
--
CREATE  PROC dbo.mmsClubUsageStat_ClubUniqueUsageSummary_Scheduled
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

--  DECLARE @Yesterday DATETIME
  DECLARE @FirstOfLastMonth DATETIME
--  DECLARE @ToDay DATETIME
  DECLARE @EndOfLastMonth DATETIME

--  SET @Yesterday  =  DATEADD(dd, -1, CONVERT(DATETIME, CONVERT(VARCHAR, GETDATE(), 102), 102))
--  SET @FirstOfMonth  =  CONVERT(DATETIME, SUBSTRING(CONVERT(VARCHAR, @yesterday, 112),1,6) + '01', 112)
--  SET @ToDay  =  CONVERT(DATETIME, CONVERT(VARCHAR, GETDATE(), 102), 102)
  SET @FirstOfLastMonth  =  CONVERT(DATETIME, SUBSTRING(CONVERT(VARCHAR, DateAdd(Month, -1, GetDate()), 112), 1, 6) + '01', 112)
  SET @EndOfLastMonth  =  DateAdd(Day, -1, CONVERT(DATETIME, SUBSTRING(CONVERT(VARCHAR, GetDate(), 112), 1, 6) + '01', 112))

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

CREATE TABLE #Memberships (ClubName VARCHAR(50), MembershipID INT, 
	UniqueMemberships INT)
CREATE TABLE #UniqueMemberships (UniqueMembershipCount INT)
CREATE TABLE #UniqueRegionMemberships (RegionDescription VARCHAR(50), UniqueRegionMembershipCount INT)

INSERT INTO #Memberships (ClubName, MembershipID)
SELECT C.ClubName, COUNT (DISTINCT (M.MembershipID)) MembershipID
  FROM dbo.vMemberUsage MU
  JOIN dbo.vClub C
       ON MU.ClubID = C.ClubID AND C.DisplayUIFlag = 1
  JOIN dbo.vValRegion VR
       ON C.ValRegionID = VR.ValRegionID
  JOIN dbo.vMember M
       ON MU.MemberID = M.MemberID
 WHERE MU.UsageDateTime BETWEEN @FirstOfLastMonth AND @EndOfLastMonth
-- WHERE MU.UsageDateTime BETWEEN @FirstOfMonth AND @ToDay
 GROUP BY C.ClubName

INSERT INTO #UniqueMemberships (UniqueMembershipCount)
SELECT Count (Distinct (M.MembershipID)) UniqueMembershipCount
  FROM dbo.vMemberUsage MU
  JOIN dbo.vClub C
       ON MU.ClubID = C.ClubID AND C.DisplayUIFlag = 1
  JOIN dbo.vValRegion VR
       ON C.ValRegionID = VR.ValRegionID
  JOIN dbo.vMember M
       ON MU.MemberID = M.MemberID
  JOIN #Memberships MS
       ON C.ClubName = MS.ClubName
 WHERE MU.UsageDateTime BETWEEN @FirstOfLastMonth AND @EndOfLastMonth
-- WHERE MU.UsageDateTime BETWEEN @FirstOfMonth AND @ToDay

UPDATE #Memberships SET UniqueMemberships = UniqueMembershipCount 
	FROM #UniqueMemberships

INSERT INTO #UniqueRegionMemberships (RegionDescription, UniqueRegionMembershipCount)
SELECT VR.Description RegionDescription, 
	Count (Distinct (M.MembershipID)) UniqueMembershipCount
  FROM dbo.vMemberUsage MU
  JOIN dbo.vClub C
       ON MU.ClubID = C.ClubID AND C.DisplayUIFlag = 1
  JOIN dbo.vValRegion VR
       ON C.ValRegionID = VR.ValRegionID
  JOIN dbo.vMember M
       ON MU.MemberID = M.MemberID
  JOIN #Memberships MS
       ON C.ClubName = MS.ClubName
 WHERE MU.UsageDateTime BETWEEN @FirstOfLastMonth AND @EndOfLastMonth
-- WHERE MU.UsageDateTime BETWEEN @FirstOfMonth AND @ToDay
 GROUP BY VR.Description

SELECT C.ClubName, Count (MU.MemberUsageID) MemberUsageIDCount, 
       VR.Description RegionDescription,
       MS.MembershipID, MS.UniqueMemberships, URM.UniqueRegionMembershipCount
  FROM dbo.vMemberUsage MU
  JOIN dbo.vClub C
       ON MU.ClubID = C.ClubID AND C.DisplayUIFlag = 1
  JOIN dbo.vValRegion VR
       ON C.ValRegionID = VR.ValRegionID
  JOIN dbo.vMember M
       ON MU.MemberID = M.MemberID
  JOIN #Memberships MS
       ON C.ClubName = MS.ClubName
  JOIN #UniqueRegionMemberships URM
       ON VR.Description = URM.RegionDescription
 WHERE MU.UsageDateTime BETWEEN @FirstOfLastMonth AND @EndOfLastMonth
-- WHERE MU.UsageDateTime BETWEEN @FirstOfMonth AND @ToDay
 GROUP BY C.ClubName, VR.Description, MS.MembershipID,
	MS.UniqueMemberships, URM.UniqueRegionMembershipCount

DROP TABLE #Memberships
DROP TABLE #UniqueMemberships
DROP TABLE #UniqueRegionMemberships

-- Report Logging
UPDATE HyperionReportLog
SET EndDateTime = getdate()
WHERE ReportLogID = @Identity

END



