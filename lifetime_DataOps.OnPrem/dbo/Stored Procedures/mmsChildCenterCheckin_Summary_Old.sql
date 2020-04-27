





------ This query returns total check-ins to the Child Center  for selected clubs within
------  a selected date range


CREATE      PROCEDURE  dbo.mmsChildCenterCheckin_Summary_Old(
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


SELECT R.Description AS RegionDescription, C.ClubName, COUNT(CCU.ChildCenterUsageID) AS CheckInCount
  FROM dbo.vClub C
  JOIN dbo.vChildCenterUsage CCU
    ON  C.ClubID=CCU.ClubID
  JOIN #Clubs tC
    ON  C.ClubID = tC.ClubID
  JOIN dbo.vValRegion R
    ON C.ValRegionID = R.ValRegionID
 WHERE CCU.CheckInDateTime >= @StartDate AND 
       CCU.CheckInDateTime <= @EndDate
 GROUP BY R.Description, C.ClubName

DROP TABLE #Clubs
DROP TABLE #tmpList

-- Report Logging
UPDATE HyperionReportLog
SET EndDateTime = getdate()
WHERE ReportLogID = @Identity

END







