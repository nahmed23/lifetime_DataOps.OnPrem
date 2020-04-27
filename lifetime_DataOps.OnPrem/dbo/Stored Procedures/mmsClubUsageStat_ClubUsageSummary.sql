
--
-- Returns Usage counts by club and gender
--
-- Parameters: a usage date range and a bar separated list of clubnames
-- Exec mmsClubUsageStat_ClubUsageSummary '1|2|3|4|5|6|7|8|9|10|11|176|172|177|173|175|171|170|174|12|13','5/1/07','5/31/07'
--
--
CREATE  PROC [dbo].[mmsClubUsageStat_ClubUsageSummary](
  @ClubIDList VARCHAR(2000),
  @UsageStartDate SMALLDATETIME,
  @UsageEndDate SMALLDATETIME
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

DECLARE @ReportStartDate  datetime
DECLARE @ReportEndDate  datetime

SET @ReportStartDate = @UsageStartDate
SET @ReportEndDate = dateadd(mi,-1,@UsageEndDate) 

CREATE TABLE #tmpList (StringField VARCHAR(15)) --equivelent to ClubID
CREATE TABLE #Members (ClubID INT, Gender CHAR(1), MemberID INT, MembershipID INT)
CREATE TABLE #Memberships (ClubID INT, MembershipID INT)
CREATE TABLE #Usages (ClubID INT, Gender CHAR(1), Usages INT)
CREATE TABLE #Clubs (ClubID VARCHAR(15))
CREATE TABLE #GuestCount (ClubID INT, TotalGuest INT)

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

IF @ClubIDList <> 'All'
BEGIN
--   INSERT INTO #Clubs EXEC procParseStringList @ClubList
	EXEC dbo.procParseStringList @ClubIDList --inserts ClubIds into #tmpList
    INSERT INTO #Clubs (ClubID) SELECT StringField FROM #tmpList
    TRUNCATE TABLE #tmpList
END
ELSE
BEGIN
--   INSERT INTO #Clubs VALUES('All') 
	INSERT INTO #Clubs select clubid from vclub
END

--Find all Members that meet the usage criteria
INSERT INTO #Members (ClubID, Gender, MemberID, MembershipID)
SELECT DISTINCT MU.ClubID, M.Gender, M.MemberID, M.MembershipID
FROM vMember M
	JOIN vMemberUsage MU
		ON MU.MemberID = M.MemberID
  JOIN #Clubs CS
       ON CS.ClubID = MU.ClubID --OR CS.ClubID = 'All'
	JOIN dbo.vClub C
		ON C.ClubID = CS.ClubID AND C.DisplayUIFlag = 1
WHERE MU.UsageDateTime BETWEEN @UsageStartDate AND @UsageEndDate

--Find the number of Memberships that checked-in
INSERT INTO #Memberships (ClubID, MembershipID)
SELECT M.ClubID, COUNT (DISTINCT(M.MembershipID)) MembershipID
FROM #Members M
GROUP BY M.ClubID

--Find the total number of Usages at a particular Club
INSERT INTO #Usages (ClubID, Gender, Usages)
SELECT MU.ClubID, M.Gender, COUNT (MU.MemberID) Usages
FROM vMemberUsage MU
    JOIN #Clubs CS
        ON CS.ClubID = MU.ClubID --OR CS.ClubID = 'All'
    JOIN vClub C
	    ON C.ClubID = CS.ClubID
    JOIN vMember M
	    ON M.MemberID = MU.MemberID  
WHERE MU.UsageDateTime BETWEEN @UsageStartDate AND @UsageEndDate AND C.DisplayUIFlag = 1
GROUP BY MU.ClubID, M.Gender

--Find the total number of Guests (member, nonmember) at a particular Club
INSERT INTO #GuestCount (ClubID,  TotalGuest)
SELECT GC.ClubID, sum(GC.MemberCount)+ sum(GC.NonMemberCount) as TotalGuest
FROM vGuestCount GC
    JOIN #Clubs CS
        ON CS.ClubID = GC.ClubID --OR CS.ClubID = 'All'
    JOIN vClub C
	    ON C.ClubID = CS.ClubID AND C.DisplayUIFlag = 1
WHERE GC.GuestCountDate BETWEEN @UsageStartDate AND @UsageEndDate 
GROUP BY GC.ClubID


--Return the Results
SELECT DISTINCT C.ClubName, U.Usages AS MemberUsageIDCount, VR.Description AS RegionDescription, 
	   M.Gender, COUNT (DISTINCT (M.MemberID)) AS MemberID, MS.MembershipID, GC.TotalGuest,
	   @ReportStartDate AS ReportStartDate, @ReportEndDate AS ReportEndDate
FROM #Members M
    JOIN vClub C
	    ON C.ClubID = M.ClubID
    JOIN dbo.vValRegion VR
        ON C.ValRegionID = VR.ValRegionID
    JOIN #Memberships MS
        ON M.ClubID = MS.ClubID
    JOIN #Usages U
	    ON U.ClubID = C.ClubID
	LEFT JOIN #GuestCount GC
		ON GC.ClubID = C.ClubID
WHERE C.DisplayUIFlag = 1 AND (
								M.Gender = U.Gender
								OR (M.Gender IS NULL AND U.Gender IS NULL)
								)
GROUP BY C.ClubName, VR.Description, M.Gender, MS.MembershipID, U.Usages, GC.TotalGuest
ORDER BY ClubName

DROP TABLE #tmpList
DROP TABLE #Memberships
DROP TABLE #Members
DROP TABLE #Clubs
DROP TABLE #GuestCount

-- Report Logging
UPDATE HyperionReportLog
SET EndDateTime = getdate()
WHERE ReportLogID = @Identity

END

