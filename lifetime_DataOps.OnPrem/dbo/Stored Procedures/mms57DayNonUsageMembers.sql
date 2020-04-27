

CREATE PROCEDURE [dbo].[mms57DayNonUsageMembers]
AS 

BEGIN
  -- This procedure sends 57 day non usage member information to siebel

  SET NOCOUNT ON
  SET XACT_ABORT ON

        DECLARE @MinDay INT
	DECLARE @MaxDay INT
	DECLARE @LastRunDate DATETIME
	DECLARE @Today DATETIME
	DECLARE @ReturnCode INT
        DECLARE @EmailGroup VARCHAR(250)
        DECLARE @DBName VARCHAR(250)
        DECLARE @subject VARCHAR(1000)

	SELECT @LastRunDate = ISNULL(LastProcessedDateTime,GETDATE()-1)
	FROM vLastProcessedDateTime
	WHERE LastProcessedDateTimeID = 1
	
	SET @Today = GETDATE()
	SET @MinDay = 57
	SET @MaxDay = 57 + DATEDIFF ( D , @LastRunDate , @Today ) -1

        --get all primary members	
	SELECT M.Memberid,M.SiebelRow_ID,C.ClubName,MS.ActivationDate
	INTO #Members
	FROM vMembership MS JOIN vMember M ON MS.MembershipID = M.MembershipID
	                    JOIN vClub C ON MS.ClubID = C.ClubID
	WHERE M.ValMemberTypeID = 1 
	  AND MS.ValMembershipStatusID = 4 
	  AND M.ActiveFlag = 1
	  AND M.SiebelRow_ID IS NOT NULL
	  AND MS.ClubID in(151,8,132,137,155,5,6,12,40,126,128,140,142,148,175,176,3,146,157,178,139,15,22,144,21)
	
        --get last usagedatetime 
	SELECT MU.MemberID,MAX(MU.UsageDateTime) UsageDateTime
	INTO #Usage
	FROM #Members M JOIN vMemberUsage MU ON MU.MemberID = M.MemberID
	GROUP BY MU.MemberID
	
        --take activationdate if there isno usage date
	SELECT M.Memberid,M.SiebelRow_ID,M.ClubName,ISNULL(UsageDateTime,ActivationDate) UsageDateTime
	INTO #MemberUsage
	FROM #Members M LEFT JOIN #Usage U ON M.MemberID = U.MemberID
	
        --delete all members that don't fall under 57 day limit.
	DELETE 
	FROM #Members 
	WHERE MemberID NOT IN(SELECT MemberID
	                        FROM #MemberUsage
	                       WHERE DATEDIFF ( D , UsageDateTime , GETDATE() ) >= @MinDay
	                         AND DATEDIFF ( D , UsageDateTime , GETDATE() ) <= @MaxDay)
	
	
	TRUNCATE TABLE tmpNonUsageMembers
	
	INSERT INTO tmpNonUsageMembers(MemberID,SiebelRow_ID,ClubName)
	SELECT Memberid,SiebelRow_ID,ClubName
	FROM #Members

	SET @ReturnCode = 0
        EXECUTE @ReturnCode = Master..xp_CmdShell 'dtsrun /SMNCODB22 /E /NDTS__MMS_57DayNonUsageMembersToSiebel'
        IF (@@ERROR <> 0 OR @ReturnCode <> 0 )
        BEGIN
              SET @EmailGroup = 'IT Database'
              SELECT @DBName = DB_Name()
              SET @subject = 'DTS of 57 day non usage Members to Siebel failed' + '(Database: ' + @@SERVERNAME + '.' + DB_Name() + ')'
				
				EXEC msdb.dbo.sp_send_dbmail @recipients= @EmailGroup,

                   @subject = @subject,
                   @dbuse = @DBName,
                  @width = 500
        END
        ELSE
        BEGIN
	      UPDATE vLastProcessedDateTime
                 SET LastProcessedDateTime = GETDATE()
               WHERE LastProcessedDateTimeID = 1
	END
	
	DROP TABLE #Members
	
	DROP TABLE #Usage
	
	DROP TABLE #MemberUsage
END

