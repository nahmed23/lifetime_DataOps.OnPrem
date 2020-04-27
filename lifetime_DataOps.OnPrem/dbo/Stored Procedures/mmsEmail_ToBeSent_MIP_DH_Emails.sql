


CREATE PROCEDURE [dbo].[mmsEmail_ToBeSent_MIP_DH_Emails]
AS 
BEGIN

SET XACT_ABORT ON
SET NOCOUNT    ON

/*Set-up variable to include the current date in the name */
DECLARE @subjectline VARCHAR (250)
SET @subjectline = 'To Be Sent MIP DH Emails ' + CONVERT(VARCHAR(12),GETDATE(),110)

DECLARE @BodyText VARCHAR(100)
SET @BodyText = 'Here are the totals for To Be Sent MIP DH Emails for ' + CONVERT(VARCHAR(12),GETDATE(),101)

DECLARE @FileName VARCHAR(50)
SET @FileName = 'ToBeSent_MIP_DH_Emails_' + CONVERT(VARCHAR(12),GETDATE(),110) +'.csv'

DECLARE @Recipients VARCHAR(100)
SET @Recipients = 'DRingeisen@lifetimefitness.com; MNelson2@lifetimefitness.com'

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

SELECT   
            club.clubname, 
            domainNamePrefix,                                             
            ship.Clubid,
            du.DepartmentHeadEmailAddress,                           
            mem.MembershipID, 
            mdu.MemberID, 
            CONVERT(VARCHAR,ship.createddatetime)  as DateMembershipCreated                                                                    
    FROM   dbo.vMIPMemberDepartmentUnit mdu               
      WITH (NOLOCK)                                       
    JOIN dbo.vDepartmentUnit du                           
      WITH (NOLOCK)                                       
      ON mdu.DepartmentUnitID = du.DepartmentUnitID       
    JOIN dbo.vMember mem                                  
      WITH (NOLOCK)                                       
      ON mem.MemberID = mdu.MemberID                      
    JOIN dbo.vValMemberType mtype                         
      WITH (NOLOCK)                                       
      ON mem.ValMemberTypeID = mtype.ValMemberTypeID      
    JOIN dbo.vMembership ship                             
      WITH (NOLOCK)                                       
      ON mem.MembershipID = ship.MembershipID             
    LEFT JOIN  dbo.vMembershipAddress ma                  
      WITH (NOLOCK)                                       
      ON ship.MembershipID = ma.MembershipID              
    LEFT JOIN dbo.vValState vs                            
      WITH (NOLOCK)                                       
      ON ma.ValStateId = vs.ValStateID                    
    LEFT OUTER JOIN dbo.vValNamePrefix prefix             
      WITH (NOLOCK)                                       
      ON mem.ValNamePrefixID = prefix.ValNamePrefixID        
    LEFT JOIN  dbo.vMembershipPhone mp                    
      WITH (NOLOCK)                                       
      ON ship.MembershipID = mp.MembershipID                        
      JOIN dbo.vClub club                         
        WITH (NOLOCK)                            
        ON     ship.ClubID =                     
             club.ClubID         
    WHERE ValPhoneTypeID = 1                              
      AND DepartmentEmailSentFlag <> 1  
    ORDER BY clubname, du.DepartmentUnitID,            
             ship.MembershipID, mdu.MemberID

SET ANSI_WARNINGS ON
SET NOCOUNT OFF
'

END
