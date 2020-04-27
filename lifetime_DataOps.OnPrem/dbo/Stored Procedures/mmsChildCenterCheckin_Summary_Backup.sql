



------ This query returns total check-ins to the Child Center  for selected clubs within
------  a selected date range
--
-- EXEC mmsChildCenterCheckin_Summary '151', '12/1/05 12:00 AM', '12/15/05 11:59 PM'
--
CREATE         PROCEDURE  dbo.mmsChildCenterCheckin_Summary_Backup(
        @ClubID  VARCHAR(1000),
        @StartDate DATETIME,
	@EndDate  DATETIME
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

CREATE TABLE #tmpList(StringField VARCHAR(50))

----Parse the ClubIDs into a temp table
EXEC procParseIntegerList @ClubID
CREATE TABLE #Clubs(ClubID INT)
INSERT INTO #Clubs(ClubID) SELECT StringField FROM #tmpList
TRUNCATE TABLE #tmpList
CREATE TABLE #Memberships (ClubName VARCHAR(50), MembershipID INT)

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

SELECT R.Description AS RegionDescription, C.ClubName, 
	COUNT(CCU.ChildCenterUsageID) AS CheckInCount,
        M.Gender, COUNT (DISTINCT (M.MemberID)) MemberID,
        MS.MembershipID,
	Sum(Case DateDiff(Year, DOB, CCU.CheckInDateTime) When 0 Then 1 Else Null End) As CheckIn0,
	Sum(Case DateDiff(Year, DOB, CCU.CheckInDateTime) When 1 Then 1 Else Null End) As CheckIn1,
	Sum(Case DateDiff(Year, DOB, CCU.CheckInDateTime) When 2 Then 1 Else Null End) As CheckIn2,
	Sum(Case DateDiff(Year, DOB, CCU.CheckInDateTime) When 3 Then 1 Else Null End) As CheckIn3,
	Sum(Case DateDiff(Year, DOB, CCU.CheckInDateTime) When 4 Then 1 Else Null End) As CheckIn4,
	Sum(Case DateDiff(Year, DOB, CCU.CheckInDateTime) When 5 Then 1 Else Null End) As CheckIn5,
	Sum(Case DateDiff(Year, DOB, CCU.CheckInDateTime) When 6 Then 1 Else Null End) As CheckIn6,
	Sum(Case DateDiff(Year, DOB, CCU.CheckInDateTime) When 7 Then 1 Else Null End) As CheckIn7,
	Sum(Case DateDiff(Year, DOB, CCU.CheckInDateTime) When 8 Then 1 Else Null End) As CheckIn8,
	Sum(Case DateDiff(Year, DOB, CCU.CheckInDateTime) When 9 Then 1 Else Null End) As CheckIn9,
	Sum(Case DateDiff(Year, DOB, CCU.CheckInDateTime) When 10 Then 1 Else Null End) As CheckIn10,
	Sum(Case DateDiff(Year, DOB, CCU.CheckInDateTime) When 11 Then 1 Else Null End) As CheckIn11,
	Sum(Case DateDiff(Year, DOB, CCU.CheckInDateTime) When 12 Then 1 Else Null End) As CheckIn12,
	Sum(Case M.Gender When 'M' Then 1 Else Null End) As MaleCheckIns,
	Sum(Case M.Gender When 'F' Then 1 Else Null End) As FemaleCheckIns
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
 WHERE CCU.CheckInDateTime >= @StartDate AND 
       CCU.CheckInDateTime <= @EndDate
 GROUP BY R.Description, C.ClubName, M.Gender, MS.MembershipID

DROP TABLE #Clubs
DROP TABLE #tmpList
DROP TABLE #Memberships

-- Report Logging
UPDATE HyperionReportLog
SET EndDateTime = getdate()
WHERE ReportLogID = @Identity

END



