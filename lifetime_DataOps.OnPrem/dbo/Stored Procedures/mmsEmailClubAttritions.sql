

CREATE PROCEDURE [dbo].[mmsEmailClubAttritions]
AS 
BEGIN

/* Counts the number of memberships that have terminated MTD and whether or not they had a myLT account */

SET XACT_ABORT ON
SET NOCOUNT    ON

/*Set-up variable to include the current date in the name */
DECLARE @subjectline VARCHAR (250)
SET @subjectline = 'Attritions by Club ' + CONVERT(VARCHAR(12),GETDATE(),110)

DECLARE @BodyText VARCHAR(100)
SET @BodyText = 'Here are the current totals for Attritions by Club for ' + CONVERT(VARCHAR(12),GETDATE(),101)

DECLARE @FileName VARCHAR(50)
SET @FileName = 'Attritions_By_Club_' + CONVERT(VARCHAR(12),GETDATE(),110) +'.csv'

DECLARE @Recipients VARCHAR(100)
SET @Recipients = 'beverson@lifetimefitness.com'

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

SELECT c.ClubID, c.ClubName, c.ClubCode, ISNULL(COUNT(DISTINCT tui.Member_ID),0) [Connected Attrition], ISNULL(COUNT(DISTINCT m.MemberID) - COUNT(DISTINCT tui.Member_ID),0) [Non-Connected Attrition], ISNULL(COUNT(DISTINCT m.MemberID),0) [Total Attrition]
FROM vClub c
LEFT JOIN vMembership ms
  ON (c.ClubID = ms.ClubID
	  AND ExpirationDate >= DATEADD(DD, -1*(DATEPART(DD,DATEADD(DD,-1,GETDATE())))+1,CAST(DATEADD(DD,-1,GETDATE()) AS VARCHAR(11))) --First of the Month (from Yesterday)
	  AND ExpirationDate < CAST(GETDATE() AS VARCHAR(11)))
LEFT JOIN vMember m
  ON (m.MembershipID = ms.MembershipID AND m.ValMemberTypeID <> 4)
LEFT JOIN tmpLTFUserIdentity tui
  ON tui.Member_ID = m.MemberID
WHERE c.DisplayUIFlag = 1
GROUP BY c.ClubID, c.ClubName, c.ClubCode
ORDER BY ClubName

SET ANSI_WARNINGS ON
SET NOCOUNT OFF
'

END

