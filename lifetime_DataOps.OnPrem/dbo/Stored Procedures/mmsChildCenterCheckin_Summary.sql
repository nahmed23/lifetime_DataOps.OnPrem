


------ This query returns total check-ins to the Child Center  for selected clubs within
------  a selected date range
--
-- EXEC mmsChildCenterCheckin_Summary '137', '2/1/06 12:00 AM', '2/28/06 11:59 PM'
--
CREATE            PROCEDURE  [dbo].[mmsChildCenterCheckin_Summary](
        @ClubID  VARCHAR(1000),
        @StartDate DATETIME,
	@EndDate  DATETIME
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

CREATE TABLE #tmpList(StringField VARCHAR(50))
CREATE TABLE #GuestCount (ClubID INT, TotalGuest INT)
CREATE TABLE #Clubs(ClubID INT)

-- Report Logging
DECLARE @Identity AS INT
INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
SET @Identity = @@IDENTITY


----Parse the ClubIDs into a temp table
IF @ClubID <> 'All'
BEGIN
	EXEC dbo.procParseStringList @ClubID --inserts ClubIds into #tmpList
    INSERT INTO #Clubs (ClubID) SELECT StringField FROM #tmpList
    TRUNCATE TABLE #tmpList
END
ELSE
BEGIN
--   INSERT INTO #Clubs VALUES('All') 
	INSERT INTO #Clubs select clubid from vclub
END

CREATE TABLE #Memberships (ClubName VARCHAR(50), MembershipID INT)
CREATE TABLE #ChildCenterUsage (RegionDescription VARCHAR(50), ClubName VARCHAR(50), 
	Gender VARCHAR(1), ChildCenterUsageID INT, MemberID INT, 
	MembershipID INT, CheckIn INT, MaleCheckIns INT, FemaleCheckIns INT, TotalGuest INT,
	ReportStartDate DATETIME, ReportEndDate DATETIME)

INSERT INTO #Memberships (ClubName, MembershipID)
SELECT C.ClubName, COUNT (DISTINCT (M.MembershipID)) MembershipID
  FROM dbo.vChildCenterUsage CCU
  JOIN dbo.vClub C
       ON CCU.ClubID = C.ClubID
  JOIN #Clubs CS
       ON C.ClubID = CS.ClubID AND C.DisplayUIFlag = 1
  JOIN dbo.vValRegion VR
       ON C.ValRegionID = VR.ValRegionID
  JOIN dbo.vMember M
       ON CCU.MemberID = M.MemberID
 WHERE CCU.CheckInDateTime >= @StartDate AND 
	CCU.CheckInDateTime <= @EndDate
 GROUP BY C.ClubName

--Find the total number of Guests (member, nonmember) at a particular Club
INSERT INTO #GuestCount (ClubID,  TotalGuest)
SELECT GC.ClubID, sum(GC.MemberChildCount)+ sum(GC.NonMemberChildCount) as TotalGuest
FROM vGuestCount GC
    JOIN #Clubs CS
        ON CS.ClubID = GC.ClubID --OR CS.ClubID = 'All'
    JOIN vClub C
	    ON C.ClubID = CS.ClubID AND C.DisplayUIFlag = 1
WHERE GC.GuestCountDate BETWEEN @StartDate AND @EndDate 
GROUP BY GC.ClubID


INSERT INTO #ChildCenterUsage (RegionDescription, ClubName, 
	ChildCenterUsageID, Gender, MemberID, MembershipID, 
	CheckIn, MaleCheckIns, FemaleCheckIns, TotalGuest,
	ReportStartDate, ReportEndDate)
SELECT R.Description AS RegionDescription, C.ClubName, 
	CCU.ChildCenterUsageID, M.Gender, M.MemberID, MS.MembershipID,
	CheckIn =
	Case When Month(M.DOB) < Month(CCU.CheckInDateTime) 
             Then DateDiff(Year, M.DOB, CCU.CheckInDateTime)
             WHEN (Month(M.DOB)= Month(CCU.CheckInDateTime) AND 
                  Day(M.DOB) <= Day(CCU.CheckInDateTime))
             THEN DateDiff(Year, M.DOB, CCU.CheckInDateTime)
             Else (DateDiff(Year, M.DOB, CCU.CheckInDateTime) - 1)
	End,
	Case M.Gender When 'M' Then 1 Else Null End As MaleCheckIns,
	Case M.Gender When 'F' Then 1 Else Null End As FemaleCheckIns,
	TotalGuest,
	@StartDate AS ReportStartDate, dateadd(mi,-1,@EndDate) AS ReportEndDate

  FROM dbo.vClub C
  JOIN dbo.vChildCenterUsage CCU
    ON  C.ClubID = CCU.ClubID
  JOIN #Clubs tC
    ON  C.ClubID = tC.ClubID
  JOIN dbo.vValRegion R
    ON C.ValRegionID = R.ValRegionID
  JOIN dbo.vMember M
       ON CCU.MemberID = M.MemberID
  JOIN #Memberships MS
       ON C.ClubName = MS.ClubName
  LEFT JOIN #GuestCount GC 
	ON GC.ClubID = C.ClubID
 WHERE CCU.CheckInDateTime >= @StartDate AND 
       CCU.CheckInDateTime <= @EndDate

SELECT RegionDescription, ClubName, 
	COUNT(ChildCenterUsageID) AS CheckInCount,
        Gender, COUNT (DISTINCT (MemberID)) MemberID,
        MembershipID,
	Sum(Case CheckIn When 0 Then 1 Else Null End) As CheckIn0,
	Sum(Case CheckIn When 1 Then 1 Else Null End) As CheckIn1,
	Sum(Case CheckIn When 2 Then 1 Else Null End) As CheckIn2,
	Sum(Case CheckIn When 3 Then 1 Else Null End) As CheckIn3,
	Sum(Case CheckIn When 4 Then 1 Else Null End) As CheckIn4,
	Sum(Case CheckIn When 5 Then 1 Else Null End) As CheckIn5,
	Sum(Case CheckIn When 6 Then 1 Else Null End) As CheckIn6,
	Sum(Case CheckIn When 7 Then 1 Else Null End) As CheckIn7,
	Sum(Case CheckIn When 8 Then 1 Else Null End) As CheckIn8,
	Sum(Case CheckIn When 9 Then 1 Else Null End) As CheckIn9,
	Sum(Case CheckIn When 10 Then 1 Else Null End) As CheckIn10,
	Sum(Case CheckIn When 11 Then 1 Else Null End) As CheckIn11,
	Sum(Case CheckIn When 12 Then 1 Else Null End) As CheckIn12,
	Sum(MaleCheckIns) As MaleCheckIns,
	Sum(FemaleCheckIns) As FemaleCheckIns,
	TotalGuest,
	ReportStartDate, 
	ReportEndDate
  FROM #ChildCenterUsage tCCU
 GROUP BY RegionDescription, ClubName, Gender, MembershipID, TotalGuest, ReportStartDate, ReportEndDate

DROP TABLE #Clubs
DROP TABLE #tmpList
DROP TABLE #Memberships
DROP TABLE #ChildCenterUsage
DROP TABLE #GuestCount

-- Report Logging
UPDATE HyperionReportLog
SET EndDateTime = getdate()
WHERE ReportLogID = @Identity

END

