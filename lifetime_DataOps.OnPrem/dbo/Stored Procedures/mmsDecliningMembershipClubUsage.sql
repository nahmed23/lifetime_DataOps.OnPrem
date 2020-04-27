
/*
    Returns Club Usage by Memberships who have has declining Club Usage within the last 90 days
    -Uses the bcp to create a file and place on the network

	--To test, just run this line (may need to change the file location to not overwrite production data)
	--EXEC mmsDecliningMembershipClubUsage

*/

CREATE PROC [dbo].[mmsDecliningMembershipClubUsage] 
AS
BEGIN

SET XACT_ABORT ON
SET NOCOUNT ON

DECLARE @Today   DATETIME
DECLARE @30Days  DATETIME
DECLARE @60Days  DATETIME
DECLARE @90Days  DATETIME
DECLARE @180Days DATETIME

DECLARE @StartMonthYear   CHAR(5)
DECLARE @EndMonthYear     CHAR(5)
DECLARE @FileDate         VARCHAR(8)
DECLARE @PeriodOneRange   VARCHAR(30)
DECLARE @PeriodTwoRange   VARCHAR(30)
DECLARE @PeriodThreeRange VARCHAR(30)

DECLARE @Query VARCHAR(8000)
DECLARE @Cmd   VARCHAR(8000)
DECLARE @Destination VARCHAR(200)
DECLARE @FileName VARCHAR(100)

--Set Date Ranges
SET @Today = CONVERT(DATETIME,CONVERT(VARCHAR(11),GETDATE()),102)
SELECT  @30Days  = @Today - 30,
		@60Days  = @Today - 60,
		@90Days  = @Today - 90,
		@180Days = @Today - 180,
		@StartMonthYear = CAST(DATENAME(MONTH,@Today - 1) AS CHAR(3)) + RIGHT(DATENAME(YEAR,GETDATE() - 1),2),
		@EndMonthYear   = CAST(DATENAME(MONTH,@Today - 90) AS CHAR(3)) + RIGHT(DATENAME(YEAR,GETDATE() - 1),2),
		@FileDate       = REPLACE(CONVERT(VARCHAR(10), GETDATE(), 101), '/', '')

SELECT  @PeriodOneRange = 'Period #1 (' + CAST(MONTH(@90Days) AS VARCHAR(2)) + '/' + CAST(DAY(@90Days) AS VARCHAR(2)) + '-' + 
						       CAST(MONTH(@60Days - 1) AS VARCHAR(2)) + '/' + CAST(DAY(@60Days - 1) AS VARCHAR(2)) + ')',
		@PeriodTwoRange = 'Period #2 (' + CAST(MONTH(@60Days) AS VARCHAR(2)) + '/' + CAST(DAY(@60Days) AS VARCHAR(2)) + '-' + 
						       CAST(MONTH(@30Days - 1) AS VARCHAR(2)) + '/' + CAST(DAY(@30Days - 1) AS VARCHAR(2)) + ')',
		@PeriodThreeRange = 'Period #3 (' + CAST(MONTH(@30Days) AS VARCHAR(2)) + '/' + CAST(DAY(@30Days) AS VARCHAR(2)) + '-' + 
						       CAST(MONTH(@Today - 1) AS VARCHAR(2)) + '/' + CAST(DAY(@Today - 1) AS VARCHAR(2)) + ')'

SELECT @Destination = '\\Ltfinc.net\ltfshare\Corp\Operations\Public_data\',
	   @FileName = 'ClubUsageExtract_AllActive_'+ @EndMonthYear + '_To_' + @StartMonthYear + '_' + @FileDate + '.csv'


/* Find the Active Memberships and the Primary Member Informations */
SELECT ms.MembershipID, m.LastName + ', ' + m.FirstName AS PrimaryName, 
       c.ClubName, ms.ActivationDate, mp.AreaCode + '-' + mp.Number AS PhoneNumber
INTO #ActiveMemberships
FROM vMembership ms
JOIN vMember m
  ON m.MembershipID = ms.MembershipID
JOIN vClub c
  ON c.ClubID = ms.ClubID
JOIN vMembershipPhone mp
  ON mp.MembershipID = ms.MembershipID
WHERE ms.ValMembershipStatusID <> 1 -- Not Terminated
  AND m.ValMemberTypeID = 1 --Primary
  AND ms.CancellationRequestDate IS NULL --Haven't Cancelled
  AND mp.ValPhoneTypeID = 1 --Home Phone
  AND ms.MembershipTypeID <> 134 --Not House Account
  AND ms.ActivationDate <  @90Days
  AND ms.ActivationDate >= @180Days


/* Find the Club Usage by Membership for the given Period */
--Period 1
SELECT ms.MembershipID, COUNT(mu.UsageDateTime) Usage
INTO #PeriodOne
FROM vMemberUsage mu
JOIN vMember m
  ON mu.MemberID = m.MemberID
JOIN #ActiveMemberships ms
  ON ms.MembershipID = m.MembershipID
WHERE mu.UsageDateTime >= @90Days
  AND mu.UsageDateTime < @60Days
GROUP BY ms.MembershipID

--Period 2
SELECT ms.MembershipID, COUNT(mu.UsageDateTime) Usage
INTO #PeriodTwo
FROM vMemberUsage mu
JOIN vMember m
  ON mu.MemberID = m.MemberID
JOIN #ActiveMemberships ms
  ON ms.MembershipID = m.MembershipID
WHERE mu.UsageDateTime >= @60Days
  AND mu.UsageDateTime < @30Days
GROUP BY ms.MembershipID

--Period 3
SELECT ms.MembershipID, COUNT(mu.UsageDateTime) Usage
INTO #PeriodThree
FROM vMemberUsage mu
JOIN vMember m
  ON mu.MemberID = m.MemberID
JOIN #ActiveMemberships ms
  ON ms.MembershipID = m.MembershipID
WHERE mu.UsageDateTime >= @30Days
  AND mu.UsageDateTime <  @Today
GROUP BY ms.MembershipID


--Create a global temp variable to hold the results for exporting
--ID column is to copy the results in the order the customer wants,
--    not displayed in the final results
--needs to be global so the bcp can pick it up

IF OBJECT_ID('tempdb..##Results') IS  NOT NULL
	DROP TABLE ##Results

CREATE TABLE ##Results (
	ID INT IDENTITY(1,1),
	Clubname VARCHAR(50),
	MembershipID VARCHAR(15),
	MemberName VARCHAR(120),
	PhoneNumber VARCHAR(30),
	ActivationDate VARCHAR(30),
	Period1 VARCHAR(30),
	Period2 VARCHAR(30),
	Period3 VARCHAR(30)
	)

--Create Header for Output file because the bcp command doesn't copy headers
INSERT INTO ##Results (Clubname, MembershipID, MemberName, PhoneNumber, ActivationDate, Period1, Period2, Period3)
SELECT 'Club Name', 'MembershipID', 'Primary Member Name', 'Primary Member Phone Number',  
	   'Membership Activation Date', @PeriodOneRange, @PeriodTwoRange, @PeriodThreeRange

--Compare the Period usage and add to the temp table if they meet the requirements
INSERT INTO ##Results (Clubname, MembershipID, MemberName, PhoneNumber, ActivationDate, Period1, Period2, Period3)
SELECT '"' + ms.ClubName + '"'  [Club Name], CAST(ms.MembershipID AS VARCHAR(11)), '"' + PrimaryName + '"' [Primary Member Name], 
       PhoneNumber [Primary Member Phone Number], CONVERT(VARCHAR(8),ms.ActivationDate,1) [Membership Activation Date],
       CAST(ISNULL(p1.Usage,0) AS VARCHAR(4)), --[Period #1 (' + @PeriodOneRange + ')],
       CAST(ISNULL(p2.Usage,0) AS VARCHAR(4)), --[Period #2 (' + @PeriodTwoRange + ')], 
       CAST(ISNULL(p3.Usage,0) AS VARCHAR(4)) --[Period #3 (' + @PeriodThreeRange + ')]
FROM #ActiveMemberships ms
LEFT JOIN #PeriodOne p1
  ON p1.MembershipID = ms.MembershipID
LEFT JOIN #PeriodTwo p2
  ON p2.MembershipID = ms.MembershipID
LEFT JOIN #PeriodThree p3
  ON p3.MembershipID = ms.MembershipID
WHERE ISNULL(p1.Usage,0) > ISNULL(p2.Usage,0)
  AND ISNULL(p2.Usage,0) > ISNULL(p3.Usage,0)
ORDER BY ms.ClubName, ms.MembershipID

--if not running on a default instance, add \instname to localhost at the end of the string
SET @Cmd = 'bcp "SELECT Clubname, MembershipID, MemberName, PhoneNumber, ActivationDate, Period1, Period2, Period3 FROM ##Results ORDER BY ID" queryout "' + @Destination + @FileName + '" -c -t , -T -S localhost' 

EXEC master.dbo.xp_cmdshell @cmd

--Cleanup
DROP TABLE #ActiveMemberships
DROP TABLE #PeriodOne
DROP TABLE #PeriodTwo
DROP TABLE #PeriodThree
DROP TABLE ##Results

END
