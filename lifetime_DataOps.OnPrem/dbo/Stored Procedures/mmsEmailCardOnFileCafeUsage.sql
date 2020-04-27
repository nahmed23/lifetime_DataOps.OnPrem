


CREATE PROCEDURE [dbo].[mmsEmailCardOnFileCafeUsage]
AS 
BEGIN

SET XACT_ABORT ON
SET NOCOUNT    ON

/*Set-up variable to include the current date in the name */
DECLARE @subjectline VARCHAR (250)
SET @subjectline = 'Card On File Cafe Usage'

DECLARE @BodyText VARCHAR(100)

DECLARE @FileName VARCHAR(50)
SET @FileName = 'CardOnFile_Cafe_Usage' + CONVERT(VARCHAR(12),GETDATE(),110) +'.csv'

DECLARE @Recipients VARCHAR(100)
SET @Recipients = 'JReilly@lifetimefitness.com;LShiffman@lifetimefitness.com'

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

select m.memberid,m.membershipid,m.firstname,m.lastname,m.dob dateofbirth,m.gender,mu.usagedatetime ClubUsageDateTime,ptct.transactiondatetime CafeUsageDateTime,ptct.TranAmount
from vPTCreditCardTransaction ptct 
join vPTCreditCardBatch pccb on  ptct.PTCreditCardBatchID = pccb.PTCreditCardBatchID
join vPTCreditCardTerminal pcct on pccb.PTCreditCardTerminalID = pcct.PTCreditCardTerminalID
join vmember m on ptct.memberid = m.memberid
join vmembership ms on m.membershipid = ms.membershipid
join vmemberusage mu on m.memberid = mu.memberid
where cardonfileflag  = 1 and voidedflag = 0
and ptct.transactiondatetime >= convert(varchar,dateadd(dd,-DATEPART (dw,getdate()-1)+2,getdate()-1),110)
and ptct.transactiondatetime < convert(varchar,dateadd(dd,-DATEPART (dw,getdate()-1)+9,getdate()-1),110)
and mu.usagedatetime >= convert(varchar,dateadd(dd,-DATEPART (dw,getdate()-1)+2,getdate()-1),110)
and mu.usagedatetime < convert(varchar,dateadd(dd,-DATEPART (dw,getdate()-1)+9,getdate()-1),110)
and pcct.clubid = 151
and mu.clubid = 151
and pcct.description like ''%Cafe%''
order by m.memberid,mu.usagedatetime,ptct.transactiondatetime
SET ANSI_WARNINGS ON
SET NOCOUNT OFF'

END

