



--
-- Returns Usage counts by Club for Age and Time Ranges
--
-- Parameters: a usage date range and a bar separated list of clubnames
--
-- EXEC mmsClubUsageStat_RegionalUsageSummary '7|3', '2/1/06 12:00 AM', '2/15/06 11:59 PM'
--
CREATE                PROC dbo.mmsClubUsageStat_RegionalUsageSummary (
  @RegionIDList VARCHAR(1000),
  @UsageStartDate SMALLDATETIME,
  @UsageEndDate SMALLDATETIME
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

--DECLARE @RegionIDList VARCHAR(1000)
--DECLARE @UsageStartDate SMALLDATETIME
--DECLARE @UsageEndDate SMALLDATETIME

--SET @RegionIDList = '3|7'
--SET @UsageStartDate = '12/1/05 12:00 AM'
--SET @UsageEndDate = '12/31/05 11:59 PM'

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

CREATE TABLE #tmpList (StringField VARCHAR(50))
CREATE TABLE #Regions (RegionID INT)
CREATE TABLE #MembershipsByHourandAge (RegionDescription VARCHAR(50),
	Gender VARCHAR(1), Age INT, DailyHour INT, MemberUsageCount INT)
CREATE TABLE #MembershipsByAgeRange (RegionDescription VARCHAR(50),
	MaleAgeU19 INT, MaleAge19_25 INT, MaleAge26_40 INT, 
	MaleAge41_55 INT, MaleAgeOver55 INT, 
	FemaleAgeU19 INT, FemaleAge19_25 INT, FemaleAge26_40 INT, 
	FemaleAge41_55 INT, FemaleAgeOver55 INT, DailyHour INT)
CREATE TABLE #RegionalMemberships (RegionDescription VARCHAR(50),
	TimeSortOption INT, TimeRange VARCHAR(25), MaleAgeU19 INT, 
	MaleAge19_25 INT, MaleAge26_40 INT, MaleAge41_55 INT,
	MaleAgeOver55 INT, FemaleAgeU19 INT, FemaleAge19_25 INT,
	FemaleAge26_40 INT, FemaleAge41_55 INT, FemaleAgeOver55 INT)
EXEC procParseIntegerList @RegionIDList
INSERT INTO #Regions (RegionID) SELECT StringField FROM #tmpList
TRUNCATE TABLE #tmpList

INSERT INTO #MembershipsByHourandAge (RegionDescription, 
	Gender, Age, DailyHour, MemberUsageCount)
SELECT VR.Description RegionDescription, M.Gender,
	Age =
	Case When Month(M.DOB) <= Month(MU.UsageDateTime) Then DateDiff(Year, M.DOB, MU.UsageDateTime)
	Else DateDiff(Year, M.DOB, MU.UsageDateTime) - 1
	End,
--	DateDiff(Year, M.DOB, MU.UsageDateTime) Age, 
--	DateDiff(Year, M.DOB, @UsageStartDate) Age, 
	DatePart(Hour, MU.UsageDateTime) DailyHour, 
	COUNT (MU.MemberUsageID) MemberUsageCount
  FROM dbo.vMemberUsage MU
  JOIN dbo.vClub C
       ON MU.ClubID = C.ClubID AND C.DisplayUIFlag = 1
--  JOIN #Clubs CS
--       ON C.ClubName = CS.ClubName AND C.DisplayUIFlag = 1
  JOIN dbo.vValRegion VR
       ON C.ValRegionID = VR.ValRegionID
  JOIN #Regions RS
       ON VR.ValRegionID = RS.RegionID
  JOIN dbo.vMember M
       ON MU.MemberID = M.MemberID
 WHERE MU.UsageDateTime BETWEEN @UsageStartDate AND @UsageEndDate
-- GROUP BY VR.Description, M.Gender, DateDiff(Year, M.DOB, @UsageStartDate), DatePart(Hour, MU.UsageDateTime)
 GROUP BY VR.Description, M.Gender, DateDiff(Year, M.DOB, MU.UsageDateTime), 
	DatePart(Hour, MU.UsageDateTime), M.DOB, MU.UsageDateTime

INSERT INTO #MembershipsByAgeRange (RegionDescription,
	MaleAgeU19, MaleAge19_25, MaleAge26_40, MaleAge41_55, MaleAgeOver55,
	FemaleAgeU19, FemaleAge19_25, FemaleAge26_40, FemaleAge41_55, 
	FemaleAgeOver55, DailyHour)
SELECT RegionDescription, 
	Sum( Case When Gender = 'M' and Age < 19 Then MemberUsageCount Else 0 End) As MaleAgeU19,
	Sum( Case When Gender = 'M' and Age Between 19 and 25 Then MemberUsageCount Else 0 End) As MaleAge19_25,
	Sum( Case When Gender = 'M' and Age Between 26 and 40 Then MemberUsageCount Else 0 End) As MaleAge26_40,
	Sum( Case When Gender = 'M' and Age Between 41 and 55 Then MemberUsageCount Else 0 End) As MaleAge41_55,
	Sum( Case When Gender = 'M' and Age > 55 Then MemberUsageCount Else 0 End) As MaleAgeOver55,
	Sum( Case When Gender = 'F' and Age < 19 Then MemberUsageCount Else 0 End) As FemaleAgeU19,
	Sum( Case When Gender = 'F' and Age Between 19 and 25 Then MemberUsageCount Else 0 End) As FemaleAge19_25,
	Sum( Case When Gender = 'F' and Age Between 26 and 40 Then MemberUsageCount Else 0 End) As FemaleAge26_40,
	Sum( Case When Gender = 'F' and Age Between 41 and 55 Then MemberUsageCount Else 0 End) As FemaleAge41_55,
	Sum( Case When Gender = 'F' and Age > 55 Then MemberUsageCount Else 0 End) As FemaleAgeOver55,
	DailyHour
  FROM #MembershipsByHourandAge
 GROUP BY RegionDescription, DailyHour

DECLARE @RegionDescription VARCHAR(50),
	@TimeSortOption INT, @TimeRange VARCHAR(25), @MaleAgeU19 INT, 
	@MaleAge19_25 INT, @MaleAge26_40 INT, @MaleAge41_55 INT,
	@MaleAgeOver55 INT, @FemaleAgeU19 INT, @FemaleAge19_25 INT,
	@FemaleAge26_40 INT, @FemaleAge41_55 INT, @FemaleAgeOver55 INT,
	@DailyHour INT

DECLARE Usage_Cursor CURSOR FOR
	SELECT RegionDescription,
		MaleAgeU19, MaleAge19_25, MaleAge26_40, MaleAge41_55,
		MaleAgeOver55, FemaleAgeU19, FemaleAge19_25, FemaleAge26_40,
		FemaleAge41_55, FemaleAgeOver55, DailyHour
	FROM #MembershipsByAgeRange

   OPEN Usage_Cursor

   FETCH NEXT FROM Usage_Cursor INTO 
  	@RegionDescription,
	@MaleAgeU19, @MaleAge19_25, @MaleAge26_40, @MaleAge41_55,
	@MaleAgeOver55,	@FemaleAgeU19, @FemaleAge19_25, @FemaleAge26_40,
	@FemaleAge41_55, @FemaleAgeOver55, @DailyHour

   WHILE @@FETCH_STATUS = 0

   BEGIN
  -- ********************************
  -- Time Range 5 - 9 AM
  -- ********************************
  If @DailyHour Between 5 and 8
	BEGIN
	  INSERT INTO #RegionalMemberships (RegionDescription,
		TimeSortOption, TimeRange, MaleAgeU19, MaleAge19_25,
		MaleAge26_40, MaleAge41_55, MaleAgeOver55,
		FemaleAgeU19, FemaleAge19_25, FemaleAge26_40,
		FemaleAge41_55, FemaleAgeOver55)
	  SELECT @RegionDescription, 1, '5:00 AM - 9:00 AM',
		@MaleAgeU19, @MaleAge19_25, @MaleAge26_40, @MaleAge41_55,
		@MaleAgeOver55, @FemaleAgeU19, @FemaleAge19_25, 
		@FemaleAge26_40, @FemaleAge41_55, @FemaleAgeOver55
	END

  -- ********************************
  -- Time Range 11 - 1 PM
  -- ********************************
  If @DailyHour Between 11 and 12
	BEGIN
	  INSERT INTO #RegionalMemberships (RegionDescription,
		TimeSortOption, TimeRange, MaleAgeU19, MaleAge19_25,
		MaleAge26_40, MaleAge41_55, MaleAgeOver55,
		FemaleAgeU19, FemaleAge19_25, FemaleAge26_40,
		FemaleAge41_55, FemaleAgeOver55)
	  SELECT @RegionDescription, 2, '11:00 AM - 1:00 PM',
		@MaleAgeU19, @MaleAge19_25, @MaleAge26_40, @MaleAge41_55,
		@MaleAgeOver55, @FemaleAgeU19, @FemaleAge19_25, 
		@FemaleAge26_40, @FemaleAge41_55, @FemaleAgeOver55
	END

  -- ********************************
  -- Time Range 4 - 8 PM
  -- ********************************
  If @DailyHour Between 16 and 19
	BEGIN
	  INSERT INTO #RegionalMemberships (RegionDescription,
		TimeSortOption, TimeRange, MaleAgeU19, MaleAge19_25,
		MaleAge26_40, MaleAge41_55, MaleAgeOver55,
		FemaleAgeU19, FemaleAge19_25, FemaleAge26_40,
		FemaleAge41_55, FemaleAgeOver55)
	  SELECT @RegionDescription, 3, '4:00 PM - 8:00 PM',
		@MaleAgeU19, @MaleAge19_25, @MaleAge26_40, @MaleAge41_55,
		@MaleAgeOver55, @FemaleAgeU19, @FemaleAge19_25, 
		@FemaleAge26_40, @FemaleAge41_55, @FemaleAgeOver55
	END

  -- ********************************
  -- Time Range 4 - 8 PM
  -- ********************************
  If @DailyHour in (0, 1, 2, 3, 4, 9, 10, 13, 14, 15, 20, 21, 22, 23)
	BEGIN
	  INSERT INTO #RegionalMemberships (RegionDescription,
		TimeSortOption, TimeRange, MaleAgeU19, MaleAge19_25,
		MaleAge26_40, MaleAge41_55, MaleAgeOver55,
		FemaleAgeU19, FemaleAge19_25, FemaleAge26_40,
		FemaleAge41_55, FemaleAgeOver55)
	  SELECT @RegionDescription, 4, 'Other',
		@MaleAgeU19, @MaleAge19_25, @MaleAge26_40, @MaleAge41_55,
		@MaleAgeOver55, @FemaleAgeU19, @FemaleAge19_25, 
		@FemaleAge26_40, @FemaleAge41_55, @FemaleAgeOver55
	END

FETCH NEXT FROM Usage_Cursor INTO
  	@RegionDescription,
	@MaleAgeU19, @MaleAge19_25, @MaleAge26_40, @MaleAge41_55, 
	@MaleAgeOver55,	@FemaleAgeU19, @FemaleAge19_25, @FemaleAge26_40, 
	@FemaleAge41_55, @FemaleAgeOver55, @DailyHour

END

CLOSE Usage_Cursor                    --Close cursor
DEALLOCATE Usage_Cursor               --Deallocate cursor

Select RegionDescription, TimeSortOption, TimeRange,
	Sum( MaleAgeU19 ) As MaleU19, Sum( MaleAge19_25 ) As Maleage19_25, 
	Sum( MaleAge26_40 ) As MaleAge26_40, Sum( MaleAge41_55 ) As MaleAge41_55, 
	Sum( MaleAgeOver55 ) As MaleageOver55,	Sum( FemaleAgeU19 ) As FemaleU19,
	Sum( FemaleAge19_25 ) FemaleAge19_25, Sum( FemaleAge26_40 ) As FemaleAge26_40, 
	Sum( FemaleAge41_55 ) As FemaleAge41_55, Sum( FemaleAgeOver55 ) As FemaleAgeOver55
From #RegionalMemberships
Group By RegionDescription, TimeSortOption, TimeRange
	Order By RegionDescription, TimeSortOption

DROP TABLE #Regions
DROP TABLE #tmpList
DROP TABLE #MembershipsByHourandAge
DROP TABLE #MembershipsByAgeRange
DROP TABLE #RegionalMemberships

-- Report Logging
UPDATE HyperionReportLog
SET EndDateTime = getdate()
WHERE ReportLogID = @Identity

END



