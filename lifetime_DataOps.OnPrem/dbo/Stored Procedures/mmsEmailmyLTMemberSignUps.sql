
CREATE PROCEDURE [dbo].[mmsEmailmyLTMemberSignUps]
AS
BEGIN

SET XACT_ABORT ON
SET NOCOUNT    ON


/*Set-up variable to include the current date in the name */
DECLARE @subjectline VARCHAR (250)
SET @subjectline = 'myLT Member SignUps ' + CONVERT(VARCHAR(12),GETDATE()-1,110)

DECLARE @BodyText VARCHAR(100)
SET @BodyText = 'Here are the current Members for myLT SignUps ' + CONVERT(VARCHAR(12),GETDATE()-1,101)

DECLARE @FileName VARCHAR(50)
SET @FileName = 'myLT_Member_SignUps_' + CONVERT(VARCHAR(12),GETDATE()-1,110) +'.csv'

DECLARE @Recipients VARCHAR(1000)
SET @Recipients = 'Neuman@lifetimefitness.com;ECrane@lifetimefitness.com'

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

DECLARE @Yesterday DATETIME
SELECT @Yesterday = CAST(GETDATE()-1 AS VARCHAR(11))

SELECT 
	c.ClubCode,	m.MemberID, convert(varchar,isnull(ms.CreatedDateTime,ms.ActivationDate),110) [Membership Create Date]
FROM tmpLTFUserIdentity ui WITH (NOLOCK)
JOIN vMember m WITH (NOLOCK) ON ui.member_id = m.MemberID
JOIN vMembership ms WITH (NOLOCK) ON m.MembershipID = ms.MembershipID
JOIN vClub c WITH (NOLOCK) ON ms.ClubID = c.ClubID
WHERE ValMemberTypeID <> 4
  AND ui.Date >= convert(varchar,GETDATE()-1,110)	-- just the MyLTActivations since the last time the job was run
  AND ui.Date < convert(varchar,GETDATE(),110)	
  AND ui.Status = ''Active''
ORDER BY ClubCode, m.MemberID
'

END
