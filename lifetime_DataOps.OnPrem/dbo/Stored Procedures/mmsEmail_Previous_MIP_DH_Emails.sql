
CREATE PROCEDURE [dbo].[mmsEmail_Previous_MIP_DH_Emails]
AS
BEGIN

SET ANSI_WARNINGS OFF
SET NOCOUNT ON

     SELECT   
            club.clubname, 
            domainNamePrefix,                                                
            ship.Clubid,
            du.DepartmentHeadEmailAddress,                           
            mem.MembershipID, 
            mdu.MemberID, 
            CONVERT(VARCHAR,ship.createddatetime) as DateMembershipCreated                                                                   
    FROM   Report_MMS.dbo.vMIPMemberDepartmentUnit mdu               
      WITH (NOLOCK)                                       
    JOIN Report_MMS.dbo.vDepartmentUnit du                           
      WITH (NOLOCK)                                       
      ON mdu.DepartmentUnitID = du.DepartmentUnitID       
    JOIN Report_MMS.dbo.vMember mem                                  
      WITH (NOLOCK)                                       
      ON mem.MemberID = mdu.MemberID                      
    JOIN Report_MMS.dbo.vValMemberType mtype                         
      WITH (NOLOCK)                                       
      ON mem.ValMemberTypeID = mtype.ValMemberTypeID      
    JOIN Report_MMS.dbo.vMembership ship                             
      WITH (NOLOCK)                                       
      ON mem.MembershipID = ship.MembershipID             
    LEFT JOIN  Report_MMS.dbo.vMembershipAddress ma                  
      WITH (NOLOCK)                                       
      ON ship.MembershipID = ma.MembershipID              
    LEFT JOIN Report_MMS.dbo.vValState vs                            
      WITH (NOLOCK)                                       
      ON ma.ValStateId = vs.ValStateID                   
    LEFT JOIN Report_MMS.dbo.vValNamePrefix prefix             
      WITH (NOLOCK)                                       
      ON mem.ValNamePrefixID = prefix.ValNamePrefixID        
    LEFT JOIN  Report_MMS.dbo.vMembershipPhone mp                    
      WITH (NOLOCK)                                       
      ON ship.MembershipID = mp.MembershipID                        
      JOIN Report_MMS.dbo.vClub club                         
        WITH (NOLOCK)                            
        ON     ship.ClubID =                     
             club.ClubID        
    WHERE ValPhoneTypeID = 1            
    ORDER BY clubname, du.DepartmentUnitID,            
             ship.MembershipID, mdu.MemberID

SET ANSI_WARNINGS ON
SET NOCOUNT OFF

END
