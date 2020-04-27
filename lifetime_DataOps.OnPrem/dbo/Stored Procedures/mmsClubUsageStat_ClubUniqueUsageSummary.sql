


--
-- Returns Usage counts by club and gender
--
-- Parameters: a usage date range and a bar separated list of clubnames
--
-- EXEC mmsClubUsageStat_ClubUniqueUsageSummary '176|14|153|158|10|172|149|51|7|178|1|177|53|131|160|35|12|151|146|142|148|40|144|6|173|162|159|2|175|36|143|139|137|5|30|164|167|11|166|170|141|147|21|171|128|161|15|157|156|136|8|126|150|4|152|133|50|155|22|163|154|174|9|140|132|20|52|138|3', '10/1/06 12:00 AM', '10/31/06 11:59 PM'
-- EXEC mmsClubUsageStat_ClubUniqueUsageSummary '176', '10/1/06 12:00 AM', '10/10/06 11:59 PM'
--
CREATE             PROC dbo.mmsClubUsageStat_ClubUniqueUsageSummary (
  @ClubIDList VARCHAR(2000),
  @UsageStartDate SMALLDATETIME,
  @UsageEndDate SMALLDATETIME
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

--DECLARE @ClubNameList VARCHAR(1000)
--DECLARE @UsageStartDate SMALLDATETIME
--DECLARE @UsageEndDate SMALLDATETIME

--SET @ClubNameList = 'Algonquin, IL|Chanhassen, MN'
--SET @UsageStartDate = '12/1/05 12:00 AM'
--SET @UsageEndDate = '12/15/05 11:59 PM'

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

CREATE TABLE #tmpList (StringField VARCHAR(15))
CREATE TABLE #Clubs (ClubID VARCHAR(15))
    EXEC procParseStringList @ClubIDList
    INSERT INTO #Clubs (ClubID) SELECT StringField FROM #tmpList
    TRUNCATE TABLE #tmpList
CREATE TABLE #Memberships (ClubName VARCHAR(50), MembershipID INT, 
	UniqueMemberships INT)
CREATE TABLE #UniqueMemberships (UniqueMembershipCount INT)
CREATE TABLE #UniqueRegionMemberships (RegionDescription VARCHAR(50), UniqueRegionMembershipCount INT)

INSERT INTO #Memberships (ClubName, MembershipID)
SELECT C.ClubName, COUNT (DISTINCT (M.MembershipID)) MembershipID
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
 GROUP BY C.ClubName

INSERT INTO #UniqueMemberships (UniqueMembershipCount)
SELECT Count (Distinct (M.MembershipID)) UniqueMembershipCount
  FROM dbo.vMemberUsage MU
  JOIN dbo.vClub C
       ON MU.ClubID = C.ClubID
  JOIN #Clubs CS
       ON C.ClubID = CS.ClubID AND C.DisplayUIFlag = 1
  JOIN dbo.vValRegion VR
       ON C.ValRegionID = VR.ValRegionID
  JOIN dbo.vMember M
       ON MU.MemberID = M.MemberID
  JOIN #Memberships MS
       ON C.ClubName = MS.ClubName
 WHERE MU.UsageDateTime BETWEEN @UsageStartDate AND @UsageEndDate --AND

UPDATE #Memberships SET UniqueMemberships = UniqueMembershipCount 
	FROM #UniqueMemberships

INSERT INTO #UniqueRegionMemberships (RegionDescription, UniqueRegionMembershipCount)
SELECT VR.Description RegionDescription, 
	Count (Distinct (M.MembershipID)) UniqueMembershipCount
  FROM dbo.vMemberUsage MU
  JOIN dbo.vClub C
       ON MU.ClubID = C.ClubID
  JOIN #Clubs CS
       ON C.ClubID = CS.ClubID AND C.DisplayUIFlag = 1
  JOIN dbo.vValRegion VR
       ON C.ValRegionID = VR.ValRegionID
  JOIN dbo.vMember M
       ON MU.MemberID = M.MemberID
  JOIN #Memberships MS
       ON C.ClubName = MS.ClubName
 WHERE MU.UsageDateTime BETWEEN @UsageStartDate AND @UsageEndDate --AND
 GROUP BY VR.Description

SELECT C.ClubName, Count (MU.MemberUsageID) MemberUsageIDCount, 
       VR.Description RegionDescription,
       MS.MembershipID, MS.UniqueMemberships, URM.UniqueRegionMembershipCount
  FROM dbo.vMemberUsage MU
  JOIN dbo.vClub C
       ON MU.ClubID = C.ClubID
  JOIN #Clubs CS
       ON C.ClubID = CS.ClubID AND C.DisplayUIFlag = 1
  JOIN dbo.vValRegion VR
       ON C.ValRegionID = VR.ValRegionID
  JOIN dbo.vMember M
       ON MU.MemberID = M.MemberID
  JOIN #Memberships MS
       ON C.ClubName = MS.ClubName
  JOIN #UniqueRegionMemberships URM
       ON VR.Description = URM.RegionDescription
WHERE MU.UsageDateTime BETWEEN @UsageStartDate AND @UsageEndDate
 GROUP BY C.ClubName, VR.Description, MS.MembershipID,
	MS.UniqueMemberships, URM.UniqueRegionMembershipCount

DROP TABLE #Clubs
DROP TABLE #tmpList
DROP TABLE #Memberships
DROP TABLE #UniqueMemberships
DROP TABLE #UniqueRegionMemberships

-- Report Logging
UPDATE HyperionReportLog
SET EndDateTime = getdate()
WHERE ReportLogID = @Identity

END



