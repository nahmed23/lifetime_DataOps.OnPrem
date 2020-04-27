

CREATE PROCEDURE [dbo].[mmsEmailDuplicateCCsInEFTAccount] AS
BEGIN
  SET NOCOUNT ON

    IF (SELECT top 1 count(*) FROM vEFTAccount WHERE CreditCardAccountID IS NOT NULL GROUP BY CreditCardAccountID HAVING COUNT(*) > 1) > 0
    BEGIN
   /*Set-up variable to include the current date in the name */
         DECLARE @subjectline VARCHAR (250)
         SET @subjectline = 'Duplicate CCs in EFTAccount on ' + CONVERT(VARCHAR(12),GETDATE(),110) + '(Database: ' + @@SERVERNAME + '.' + DB_Name() + ')'

         DECLARE @BodyText VARCHAR(100)
          
         DECLARE @FileName VARCHAR(50)
         SET @FileName = 'DuplicateCCs_' + CONVERT(VARCHAR(12),GETDATE(),110) +'.csv'

         DECLARE @Recipients VARCHAR(100)
         SET @Recipients = 'PPetersen@lifetimefitness.com;CHautman@lifetimefitness.com;DAlms@lifetimefitness.com'

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
					,@query='set nocount on 
                             SELECT EFT.EFTAccountID,CCA.CreditCardAccountID,MS.MembershipID,CCA.Name NameOnCC,ISNULL(M.FirstName,'''''') + '''' '''' + ISNULL(M.LastName,'''''') MemberName,VMS.Description MembershipStatus,VEFTO.Description EFTStatus
                             FROM vEFTAccount EFT JOIN vCreditCardAccount CCA ON EFT.CreditCardAccountID = CCA.CreditCardAccountID
                                  JOIN vMembership MS ON EFT.MembershipID = MS.MembershipID
                                  JOIN vMember M ON MS.MembershipID = M.MembershipID AND M.ValMemberTypeID = 1
                                  JOIN vValMembershipStatus VMS ON MS.ValMembershipStatusID = VMS.ValMembershipStatusID
                                  JOIN vValEFTOption VEFTO ON MS.ValEFTOptionID = VEFTO.ValEFTOptionID
                              WHERE EFT.CreditCardAccountID IN( SELECT CreditCardAccountID FROM vEFTAccount WHERE CreditCardAccountID IS NOT NULL GROUP BY CreditCardAccountID HAVING COUNT(*) > 1)
                              ORDER BY CCA.CreditCardAccountID'
     END

END

