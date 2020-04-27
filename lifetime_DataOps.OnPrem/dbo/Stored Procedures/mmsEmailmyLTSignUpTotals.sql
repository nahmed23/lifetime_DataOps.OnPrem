


CREATE PROCEDURE [dbo].[mmsEmailmyLTSignUpTotals]
AS
BEGIN

SET XACT_ABORT ON
SET NOCOUNT    ON
/*
Assumes DTS runs copying data to tmpLTFUserIdentity

DTS Query for tmpLTFUserIdentity (Run on LTFEB)

SELECT lui.lui_identity_status_from_datetime AS Date, m.member_id, CAST(lui.lui_identity_status AS VARCHAR(25)) AS Status
FROM LTFUserIdentity lui WITH (NOLOCK)
JOIN vLTFMember m WITH (NOLOCK)
  ON m.party_id = lui.party_id
GROUP BY lui.lui_identity_status_from_datetime, m.member_id,lui.lui_identity_status
ORDER BY Member_ID


--Old Version
--SELECT COALESCE(MIN(luil.lui_identity_status_from_datetime),lui.lui_identity_status_from_datetime) AS Date,	   m.member_id, CAST(lui.lui_identity_status AS VARCHAR(25)) AS Status
--FROM LTFUserIdentity lui WITH (NOLOCK)
--JOIN vLTFMember m WITH (NOLOCK)
--  ON m.party_id = lui.party_id
--LEFT JOIN LTFUserIdentityLog luil WITH (NOLOCK)
--  ON luil.party_id = lui.party_id
--GROUP BY lui.lui_identity_status_from_datetime, m.member_id,lui.lui_identity_status
--ORDER BY Member_ID

*/


/*Set-up variable to include the current date in the name */
DECLARE @subjectline VARCHAR (250)
SET @subjectline = 'myLT SignUps ' + CONVERT(VARCHAR(12),GETDATE(),110)

DECLARE @BodyText VARCHAR(100)
SET @BodyText = 'Here are the current totals for myLT SignUps ' + CONVERT(VARCHAR(12),GETDATE(),101)

DECLARE @FileName VARCHAR(50)
SET @FileName = 'myLT_SignUps_' + CONVERT(VARCHAR(12),GETDATE(),110) +'.csv'

DECLARE @Recipients VARCHAR(1000)
SET @Recipients = 'jhidding@lifetimefitness.com;SAndresen@lifetimefitness.com;MNeuman@lifetimefitness.com'

EXEC msdb.dbo.sp_send_dbmail 
					 @profile_name = 'sqlsrvcacct'
                    ,@recipients = @Recipients
					,@copy_recipients = 'itdatabase@lifetimefitness.com'
                    ,@subject=@subjectline
                    ,@body = @BodyText
					,@attach_query_result_as_file = 1
					,@query_attachment_filename = @FileName
					,@exclude_query_output = 1
					,@query_result_width = 1000
				    ,@query_result_separator = '	' --tab
                    ,@execute_query_database = 'Report_MMS'
					,@query='
SET ANSI_WARNINGS OFF
SET NOCOUNT ON

DECLARE @Today DATETIME
DECLARE @Date DATETIME
DECLARE @Total INT
DECLARE @Members INT
DECLARE @Employees INT
DECLARE @Active INT
DECLARE @InActive INT
DECLARE @Counter INT

--Today
SELECT @Today = CAST(GETDATE() AS VARCHAR(11))

--Set Date
SELECT @Date =  ''2008-11-01'' --DATEADD(DD,-33, @Today)

CREATE TABLE #DailyList (Date DATETIME, Members INT, Employees INT, Active INT, InActive INT, Total INT)

/* Daily SignUps */
INSERT INTO #DailyList
SELECT CAST(Date AS DATETIME) AS Date,
	   SUM(Members) Members,
	   SUM(Employees) Employees,
	   SUM(Active) Active,
	   SUM(InActive) InActive,
	   COUNT(member_id) Total
FROM (
		SELECT CAST(Date AS VARCHAR(11)) Date, member_id,
			   CASE WHEN e.EmployeeID IS NULL THEN 1 ELSE 0 END Members,
			   CASE WHEN e.EmployeeID IS NOT NULL THEN 1 ELSE 0 END Employees,
			   CASE WHEN Status = ''Active'' THEN 1 ELSE 0 END Active,
			   CASE WHEN Status <> ''Active'' THEN 1 ELSE 0 END InActive
		FROM tmpLTFUserIdentity ui WITH (NOLOCK)
		LEFT JOIN vEmployee e
		  ON (e.MemberID = ui.member_id AND e.ActiveStatusFlag = 1)
		WHERE Date < CAST(GETDATE() AS VARCHAR(11))
) AllResults
WHERE Date >= @Date
GROUP BY Date
ORDER BY Date

SELECT @Total = COUNT(DISTINCT member_id)
FROM tmpLTFUserIdentity WITH (NOLOCK)
WHERE Date < CAST(GETDATE() AS VARCHAR(11))

SELECT @Employees = COUNT(DISTINCT e.EmployeeID)
FROM tmpLTFUserIdentity ui WITH (NOLOCK)
JOIN vEmployee e WITH (NOLOCK)
  ON e.MemberID = ui.member_id
WHERE e.EmployeeID IS NOT NULL
  AND Date < CAST(GETDATE() AS VARCHAR(11))

SELECT @Members = @Total - @Employees

SELECT @Active = COUNT(member_id)
FROM tmpLTFUserIdentity WITH (NOLOCK)
WHERE Status = ''Active''
  AND Date < CAST(GETDATE() AS VARCHAR(11))

SELECT @InActive = COUNT(member_id)
FROM tmpLTFUserIdentity WITH (NOLOCK)
WHERE Status <> ''Active''
  AND Date < CAST(GETDATE() AS VARCHAR(11))

--Cumulative Results

SELECT CAST(Date AS VARCHAR(11)) Date, '''' [Daily Results:],
Members, Employees, Active, InActive, Total,
'''' [Running Totals:],
@Members - ISNULL((SELECT SUM(Members) FROM #DailyList dl2 WHERE dl2.Date > dl.Date),0) Members,
@Employees - ISNULL((SELECT SUM(Employees) FROM #DailyList dl2 WHERE dl2.Date > dl.Date),0) Employees,
@Active - ISNULL((SELECT SUM(Active) FROM #DailyList dl2 WHERE dl2.Date > dl.Date),0) Active,
@InActive - ISNULL((SELECT SUM(InActive) FROM #DailyList dl2 WHERE dl2.Date > dl.Date),0) InActive,
@Total - ISNULL((SELECT SUM(Total) FROM #DailyList dl2 WHERE dl2.Date > dl.Date),0) Total
FROM #DailyList dl
ORDER BY CAST(Date AS DATETIME)

PRINT '''' + CHAR(10)

/*** New Members and myLT Accounts ***/

DECLARE @StartDate DATETIME 
SET @StartDate = ''2008-12-02'' --Start of myLT initiative

DECLARE @EndDate DATETIME
SET @EndDate = CAST(GETDATE() AS VARCHAR(11)) --Midnight of the current Day


--Table to Display Final Results
CREATE TABLE #DateList (
	Date VARCHAR(11),
	[Total New Members] INT,
	[New Members with myLT Accounts] INT,
	[Members who visited since 12/2/08] INT,
	[Members who visited since 12/2/08 with myLT Account] INT
)


INSERT INTO #DateList
SELECT ''Total'',
(
--Total New Members after 12/2
SELECT COUNT(DISTINCT MemberID)
FROM vMember
WHERE JoinDate >= @StartDate
  AND JoinDate < @EndDate
  AND ValMemberTypeID <> 4
) AS [Total New Members],
(
--New Member with new Accounts
SELECT COUNT(DISTINCT m.MemberID)
FROM vMember m
JOIN tmpLTFUserIdentity lui
  ON lui.member_id = m.MemberID
WHERE lui.Date >= @StartDate
  AND JoinDate >= @StartDate
  AND JoinDate < @EndDate
  AND lui.Date < @EndDate
  AND ValMemberTypeID <> 4
) AS [New Members with myLT Accounts],
(
--Number of Members who visited after 12/2 
SELECT COUNT(DISTINCT mu.MemberID)
FROM vMemberUsage mu
JOIN vMember m
  ON m.MemberID = mu.MemberID
WHERE UsageDateTime >= @StartDate
  AND UsageDateTime < @EndDate
  AND ValMemberTypeID <> 4
)  AS [Members who visited since 12/2/08],
(
--Members who visited that have an account
SELECT COUNT(DISTINCT mu.MemberID) 
FROM vMemberUsage mu
JOIN vMember m
  ON m.MemberID = mu.MemberID
JOIN tmpLTFUserIdentity lui
  ON lui.member_id = m.MemberID
WHERE UsageDateTime >= @StartDate
  AND UsageDateTime < @EndDate
  AND lui.Date >= @StartDate
  AND JoinDate < @EndDate
  AND lui.Date < @EndDate
  AND ValMemberTypeID <> 4
)  AS [Members who visited since 12/2/08 with myLT Account]


/* New Members and myLT account Breakdown by Day */

--# of days for the Daily List Breakdown (Should be Positive
SET @COUNTER = 14

--New Members
SELECT JoinDate, COUNT(DISTINCT MemberID) Members
INTO #TotalNewMembers
FROM vMember
WHERE JoinDate < @Today
  AND JoinDate >= DATEADD(DD,-1*@COUNTER,@Today)
  AND ValMemberTypeID <> 4
GROUP BY JoinDate
ORDER BY JoinDate

--New Members with myLT
SELECT JoinDate, COUNT(DISTINCT MemberID) Members
INTO #NewMemberMyLTAccounts
FROM vMember m
JOIN tmpLTFUserIdentity lui
  ON lui.member_id = m.MemberID
WHERE ValMemberTypeID <> 4
  AND m.JoinDate < @Today
  AND m.JoinDate >= DATEADD(DD,-1*@COUNTER,@Today)
GROUP BY JoinDate
ORDER BY JoinDate

--Members who Checked In the last xx Days 
SELECT CAST(UsageDateTime AS VARCHAR(11)) UsageDateTime, COUNT(DISTINCT mu.MemberID) Members
INTO #MemberUsage
FROM vMemberUsage mu
JOIN vMember m
  ON m.MemberID = mu.MemberID
WHERE UsageDateTime >= DATEADD(DD,-1*@COUNTER,@Today)
  AND UsageDateTime < @Today
  AND m.JoinDate < @Today
  AND ValMemberTypeID <> 4
GROUP BY CAST(UsageDateTime AS VARCHAR(11))
ORDER BY CAST(UsageDateTime AS VARCHAR(11))

--Members with myLT who Checked In the last xx Days 
SELECT CAST(UsageDateTime AS VARCHAR(11)) UsageDateTime, COUNT(DISTINCT mu.MemberID) Members
INTO #MemberUsageMyLT
FROM vMemberUsage mu
JOIN vMember m
  ON m.MemberID = mu.MemberID
JOIN tmpLTFUserIdentity lui
  ON lui.member_id = m.MemberID
WHERE UsageDateTime >= DATEADD(DD,-1*@COUNTER,@Today)
  AND UsageDateTime < @Today
  AND m.JoinDate < @Today
  AND lui.Date >= @StartDate
  AND lui.Date < @Today
  AND ValMemberTypeID <> 4
GROUP BY CAST(UsageDateTime AS VARCHAR(11))
ORDER BY CAST(UsageDateTime AS VARCHAR(11))


--Polulate the new table with the last xx Days 
WHILE ABS(@Counter) > 0
BEGIN
	INSERT INTO #DateList
	SELECT CAST(DATEADD(DD,-1 * ABS(@Counter),@Today) AS VARCHAR(11)),0,0,0,0
	SET @Counter = ABS(@Counter) - 1
END

--Insert Results into Table
UPDATE #DateList 
SET [Total New Members] = tnm.Members
FROM #TotalNewMembers tnm
JOIN #DateList dl
  ON dl.Date = CAST(JoinDate AS VARCHAR(11))

UPDATE #DateList 
SET [New Members with myLT Accounts] = nmma.Members
FROM #NewMemberMyLTAccounts nmma
JOIN #DateList dl
  ON dl.Date = CAST(JoinDate AS VARCHAR(11))

UPDATE #DateList 
SET [Members who visited since 12/2/08] = nmu.Members
FROM #MemberUsage nmu
JOIN #DateList dl
  ON dl.Date = CAST(UsageDateTime AS VARCHAR(11))

UPDATE #DateList 
SET [Members who visited since 12/2/08 with myLT Account] = nmum.Members
FROM #MemberUsageMyLT nmum
JOIN #DateList dl
  ON dl.Date = CAST(UsageDateTime AS VARCHAR(11))

SELECT * FROM #DateList

DROP TABLE #DailyList
DROP TABLE #DateList
DROP TABLE #TotalNewMembers
DROP TABLE #NewMemberMyLTAccounts
DROP TABLE #MemberUsage
DROP TABLE #MemberUsageMyLT


SET ANSI_WARNINGS ON
SET NOCOUNT OFF
'

END


