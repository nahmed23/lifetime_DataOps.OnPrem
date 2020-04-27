

CREATE PROCEDURE [dbo].[mmsEmailActivemyLTCount]
AS 
BEGIN

/* Counts the number of memberships that have terminated MTD and whether or not they had a myLT account */

SET XACT_ABORT ON
SET NOCOUNT    ON

/*Set-up variable to include the current date in the name */
DECLARE @subjectline VARCHAR (250)
SET @subjectline = 'Active myLT Count ' + CONVERT(VARCHAR(12),GETDATE(),110)

DECLARE @BodyText VARCHAR(100)
SET @BodyText = 'Here are the current totals for Active myLT Accounts by Club for ' + CONVERT(VARCHAR(12),GETDATE(),101)

DECLARE @FileName VARCHAR(50)
SET @FileName = 'Active_myLT_By_Club_' + CONVERT(VARCHAR(12),GETDATE(),110) +'.csv'

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

SELECT C.ClubName,COUNT(*) MyLTCount 
FROM tmpLTFUserIdentity TLUI 
JOIN vMember M on TLUI.member_id = M.MemberID
JOIN vMembership MS ON M.MembershipID = MS.MembershipID
JOIN vClub C on MS.ClubID = C.ClubID
WHERE TLUI.Status = ''Active''
GROUP BY C.ClubName
ORDER BY ClubName

SET ANSI_WARNINGS ON
SET NOCOUNT OFF
'

END

