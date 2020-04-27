
-- exec mmsChildCenter_OccupancySummary '04/01/09 12:00 AM', '04/01/09 11:59 PM', '8|14'

CREATE  PROC [dbo].[mmsChildCenter_OccupancySummary]
(
	@StartDate SMALLDATETIME,
	@EndDate SMALLDATETIME,
	@ClubIDList VARCHAR(8000)	
)
AS
BEGIN

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

CREATE TABLE #tmpList (StringField VARCHAR(50))
CREATE TABLE #Clubs (ClubID VARCHAR(15))
EXEC procParseStringList @ClubIDList
INSERT INTO #Clubs (ClubID) SELECT StringField FROM #tmpList
TRUNCATE TABLE #tmpList

DECLARE @MinuteFactor INT
SET @MinuteFactor = 15


CREATE TABLE #Times (Time DATETIME)

DECLARE @Time DATETIME
SET @Time = @StartDate

WHILE @Time <= @EndDate
BEGIN
	--Only create values between 8am and 9:30pm
	IF DATEADD(HH,8,CAST(@Time AS VARCHAR(11))) <= @Time --After 8am
	   AND DATEADD(Minute,30,DATEADD(Hour,21,CAST(@Time AS VARCHAR(11)))) >= @Time --Before 9:30pm
	INSERT INTO #Times (Time)
	VALUES(@Time)

	SET @Time = DATEADD(Minute,@MinuteFactor,@Time)
END


SELECT 
R.Description AS RegionDescription,
c.ClubCode,
c.ClubID, 
c.ClubName, 
convert(varchar, t.Time,101) AS Date, 
convert(varchar, t.Time, 8) AS HourMinutes, 
ISNULL(COUNT(ccu.MemberID),0) TotalCount,
ISNULL(sum(CASE WHEN DATEDIFF(DD, M.DOB, T.TIME) < 366 THEN 1 ELSE 0 END),0) AS Infant,
ISNULL(sum(CASE WHEN DATEDIFF(DD, M.DOB, T.TIME) >= 366 THEN 1 ELSE 0 END),0) AS Child,

0 AS CheckIns_TotalCount,
0 AS CheckIns_Infant,
0 AS CheckIns_Child

FROM #Times t
CROSS JOIN #Clubs cs 
JOIN vClub c
  ON c.ClubID = cs.ClubID
JOIN vValRegion R 
       ON C.ValRegionID=R.ValRegionID
LEFT JOIN vChildCenterUsage ccu
  ON (t.Time > ccu.CheckInDateTime 
      AND t.Time <= ISNULL(ccu.CheckOutDateTime,'2999-12-31')
      AND ccu.ClubID = c.ClubID
	  AND ccu.CheckInDateTime between dateadd(hh, -10, t.Time) and dateadd(hh,10,t.Time)
     )
LEFT JOIN vMember M ON M.MemberID = ccu.MemberID
GROUP BY R.Description, c.ClubCode, c.ClubID, c.ClubName,  t.Time
--ORDER BY c.ClubID, t.Time

UNION

-- total check ins 
SELECT 
	R.Description AS RegionDescription,
	c.ClubCode,
	c.ClubID, 
	c.ClubName, 
	convert(varchar, ccu.CheckInDateTime,101) AS Date, 
	'22:00:00' AS HourMinutes, 
	0 AS TotalCount,
	0 AS Infant,
	0 AS Child,
	ISNULL(COUNT(ccu.MemberID),0) AS CheckIns_TotalCount,
	ISNULL(sum(CASE WHEN DATEDIFF(DD, M.DOB, ccu.CheckInDateTime) < 366 THEN 1 ELSE 0 END),0) AS CheckIns_Infant,
	ISNULL(sum(CASE WHEN DATEDIFF(DD, M.DOB, ccu.CheckInDateTime) >= 366 THEN 1 ELSE 0 END),0) AS CheckIns_Child

	FROM vChildCenterUsage ccu
	JOIN vClub c
	  ON ccu.ClubID = c.ClubID 
	JOIN vValRegion R 
	  ON C.ValRegionID=R.ValRegionID
	JOIN #Clubs cs 
	  ON cs.ClubID = c.ClubID  
	JOIN vMember M 
	  ON M.MemberID = ccu.MemberID
	WHERE ccu.CheckInDateTime  between @StartDate and @EndDate 
GROUP BY
	R.Description,
	c.ClubCode,
	c.ClubID, 
	c.ClubName,
	convert(varchar, ccu.CheckInDateTime,101) 

--ORDER BY c.ClubID, t.Time

DROP TABLE #Times
DROP TABLE #tmpList
DROP TABLE #Clubs


	-- Report Logging
	  UPDATE HyperionReportLog
	  SET EndDateTime = getdate()
	  WHERE ReportLogID = @Identity
END

