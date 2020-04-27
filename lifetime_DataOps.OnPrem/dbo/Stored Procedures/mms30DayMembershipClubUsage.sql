
/*
    Returns Club Usage by Memberships who have has declining Club Usage within the last 90 days
    -Uses the bcp to create a file and place on the network

	--To test, just run this line (may need to change the file location to not overwrite production data)
	--EXEC mms30DayMembershipClubUsage

*/

CREATE PROC [dbo].[mms30DayMembershipClubUsage] 
AS
BEGIN

SET XACT_ABORT ON
SET NOCOUNT ON

DECLARE @Today   DATETIME
DECLARE @FileDate VARCHAR(8)
DECLARE @StartDate DATETIME
DECLARE @EndDate DATETIME

DECLARE @30DayUsage VARCHAR(200)
DECLARE @Query VARCHAR(8000)
DECLARE @Cmd   VARCHAR(8000)
DECLARE @Destination VARCHAR(200)
DECLARE @FileName VARCHAR(100)

--Set Date Ranges
SET @Today = CONVERT(DATETIME,CONVERT(VARCHAR(11),GETDATE()),102)
SET @FileDate = REPLACE(CONVERT(VARCHAR(10), GETDATE(), 101), '/', '')

SELECT @Destination = '\\Ltfinc.net\ltfshare\Corp\Operations\Public_data\',
	   @FileName = 'ClubUsageExtract_30Days_' + @FileDate + '.txt'

SELECT @StartDate = CONVERT(DATETIME,CAST(DATEADD(DD,-31,@Today) AS VARCHAR(11)), 110),
       @EndDate = CONVERT(DATETIME,CAST(DATEADD(DD,-1,@Today) AS VARCHAR(11)), 110)

SET @30DayUsage = '30 Day Usage (' + CAST(MONTH(@StartDate) AS VARCHAR(2)) + '/' + CAST(DAY(@StartDate) AS VARCHAR(2)) + ' - ' + CAST(MONTH(@EndDate) AS VARCHAR(2)) + '/' + CAST(DAY(@EndDate) AS VARCHAR(2)) + ')'

SELECT c.ClubName, ms.MembershipID, mp.LastName + ', ' + mp.FirstName PrimaryMember, 
       phone.AreaCode + '-' + phone.Number PhoneNumber,
       ms.ActivationDate, m.MemberID
INTO #Members
FROM vMembership ms
JOIN vMember m
  ON m.MembershipID = ms.MembershipID
JOIN vClub c
  ON c.ClubID = ms.ClubID
JOIN vMember mp
  ON mp.MembershipID = ms.MembershipID
JOIN vMembershipPhone phone
  ON phone.MembershipID = ms.MembershipID
WHERE CONVERT(DATETIME,CAST(ms.ActivationDate AS VARCHAR(11)), 110) = @StartDate --30 days ago
  AND mp.ValMemberTypeID = 1 --Primary
  AND ms.ValMembershipStatusID = 4 --Active
  AND ms.ExpirationDate IS NULL --No Termination Date
  AND phone.ValPhoneTypeID = 1 --Home Phone


--Create the results set to return
IF OBJECT_ID('tempdb..##30DayResults') IS  NOT NULL
	DROP TABLE ##30DayResults

CREATE TABLE ##30DayResults (
	ID INT IDENTITY(1,1),
	Clubname VARCHAR(50),
	MembershipID VARCHAR(15),
	MemberName VARCHAR(120),
	PhoneNumber VARCHAR(30),
	ActivationDate VARCHAR(30),
	ClubUsage VARCHAR(30)
	)

--Create Header for Output file because the bcp command doesn't copy headers
INSERT INTO ##30DayResults (Clubname, MembershipID, MemberName, PhoneNumber, ActivationDate, ClubUsage)
SELECT 'Club Name', 'MembershipID', 'Primary Member Name', 'Primary Member Phone Number',  
	   'Membership Activation Date', @30DayUsage

--Find members with 4 or less visits
INSERT INTO ##30DayResults (Clubname, MembershipID, MemberName, PhoneNumber, ActivationDate, ClubUsage)
SELECT m.ClubName, m.MembershipID, m.PrimaryMember, m.PhoneNumber, m.ActivationDate, COUNT(mu.UsageDateTime)
FROM #Members m
LEFT JOIN vMemberUsage mu
  ON mu.MemberID = m.MemberID
GROUP BY m.ClubName, m.MembershipID, m.PrimaryMember, m.PhoneNumber, m.ActivationDate
HAVING COUNT(mu.UsageDateTime) < 5 --4 or less Club Usages
ORDER BY m.ClubName, m.MembershipID

--if not running on a default instance, add \instname to localhost at the end of the string
SET @Cmd = 'bcp "SELECT Clubname, MembershipID, MemberName, PhoneNumber, ActivationDate, ClubUsage FROM ##30DayResults ORDER BY ID" queryout "' + @Destination + @FileName + '" -c -T -S ' + @@SERVERNAME 

EXEC master.dbo.xp_cmdshell @cmd

--CleanUp
DROP TABLE #Members
DROP TABLE ##30DayResults

END
