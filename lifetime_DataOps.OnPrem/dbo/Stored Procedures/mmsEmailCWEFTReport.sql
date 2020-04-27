



CREATE PROCEDURE [dbo].[mmsEmailCWEFTReport]
								@RowsProcessed int output, 
								@Description  varchar(80) output
AS 
BEGIN

/* Emails EFT Account details for corporate accounts  */

SET XACT_ABORT ON
SET NOCOUNT    ON

declare @CorporateCode varchar(50)
declare @EFTAccountNumber varchar(4)
declare @ReportToEmailAddress varchar(150)
declare @FirstOfCurrentMonth varchar(150)
declare @query varchar(8000)
declare @count int

DECLARE @subjectline VARCHAR (250)
SET @subjectline = 'Corporate Wellness EFT Report'


DECLARE @BodyText VARCHAR(2000)

DECLARE @FileName VARCHAR(50)
SET @FileName = 'EFTReport' + CONVERT(VARCHAR(12),GETDATE(),110) +'.csv'


set @FirstOfCurrentMonth = convert(varchar,month(getdate())) + '/01/' + convert(varchar,year(getdate()))

select CorporateCode,EFTAccountNumber ,ReportToEmailAddress 
into #emaildata
from vCompany
where EFTAccountNumber is not null and ltrim(rtrim(EFTAccountNumber)) <> ''
  and ReportToEmailAddress is not null and ltrim(rtrim(ReportToEmailAddress)) <> ''

select @RowsProcessed = count(*) from #emaildata
select @Description = 'Number of Companies that received emails'
while (select count(*) from #emaildata) > 0
begin
   select top 1 CorporateCode,ReportToEmailAddress 
   into #top1 
   from #emaildata

   select @CorporateCode=a.CorporateCode,
          @EFTAccountNumber = b.EFTAccountNumber ,
          @ReportToEmailAddress  = a.ReportToEmailAddress 
   from #top1 a join #emaildata b on a.CorporateCode = b.CorporateCode

                 select m.MemberID,m.FirstName,m.LastName,convert( varchar(10), m.JoinDate, 110 ) as JoinDate,
	                    p.Description as MembershipType,convert( varchar(10), e.EFTDate, 110 ) as EFTDate,
	                    ves.Description as EFTStatus,e.EFTAmount,c.ClubName, vr.Description as Region
                  into #temp1
                 from   vEFT e join vMembership ms on e.MembershipID = ms.MembershipID
	                    join vMember m on ms.MembershipID = m.MembershipID
	                    join vClub c on ms.ClubID   = c.ClubID
	                    join vMembershipType  mt on ms.MembershipTypeID  = mt.MembershipTypeID
	                    join vProduct p on mt.ProductID= p.ProductID   
	                    join vValRegion   vr on c.ValRegionID= vr.ValRegionID
	                    join vValPaymentType  vpt  on e.ValPaymentTypeID   = vpt.ValPaymentTypeID
	                    join vValEFTStatus ves on e.ValEFTStatusID = ves.ValEFTStatusID
	                    left join vCompany cp on ms.CompanyID= cp.CompanyID
	                    where Right( e.MaskedAccountNumber, 4 ) = @EFTAccountNumber 
	                          and e.EFTDate between @FirstOfCurrentMonth and getdate()
	                          and m.ValMemberTypeID   = 1
	                          and cp.CorporateCode =  @CorporateCode 
             select @Count = count(*) from #temp1
   SET @BodyText = 'A Corporate EFT Report is included as an attachment to this email.  If the attached report can not be accessed or if it has been removed from this email, please contact your email support administrator for instructions to allow receipt of external attachments.  Additions and/or removals need to be requested via the Request for Change form and submitted by the 20th of this month. A total of ' + convert(varchar,@Count) + ' members were processed for the period of ' + convert(varchar,@FirstOfCurrentMonth,110) + ' to ' + convert(varchar,getdate(),110)  + '. Expand columns to view full column contents.  Do not reply to this email.  Contact your Life Time Fitness Client Services Specialist with questions.'

   set @query = 'SET NOCOUNT    ON
                 select m.MemberID,m.FirstName,m.LastName,convert( varchar(10), m.JoinDate, 110 ) as JoinDate,
	                    p.Description as MembershipType,convert( varchar(10), e.EFTDate, 110 ) as EFTDate,
	                    ves.Description as EFTStatus,e.EFTAmount,c.ClubName, vr.Description as Region
	             from   vEFT e join vMembership ms on e.MembershipID = ms.MembershipID
	                    join vMember m on ms.MembershipID = m.MembershipID
	                    join vClub c on ms.ClubID   = c.ClubID
	                    join vMembershipType  mt on ms.MembershipTypeID  = mt.MembershipTypeID
	                    join vProduct p on mt.ProductID= p.ProductID   
	                    join vValRegion   vr on c.ValRegionID= vr.ValRegionID
	                    join vValPaymentType  vpt  on e.ValPaymentTypeID   = vpt.ValPaymentTypeID
	                    join vValEFTStatus ves on e.ValEFTStatusID = ves.ValEFTStatusID
	                    left join vCompany cp on ms.CompanyID= cp.CompanyID
	                    where Right( e.MaskedAccountNumber, 4 ) = ''' + @EFTAccountNumber + '''
	                          and e.EFTDate between ''' + convert(varchar,@FirstOfCurrentMonth)  + ''' and  ''' + convert(varchar,getdate(),110) + '''
	                          and m.ValMemberTypeID   = 1
	                          and cp.CorporateCode = ''' + @CorporateCode + '''
	                    order  by
	                     Region,
	                     ClubName,
	                     LastName'
       
      EXEC msdb.dbo.sp_send_dbmail 
					 @profile_name = 'LifeTime'
                    ,@recipients = @ReportToEmailAddress
					--,@copy_recipients = 'ITDatabase@lifetimefitness.com'
                    ,@subject=@subjectline
                    ,@body = @BodyText
					,@attach_query_result_as_file = 1
					,@query_attachment_filename = @FileName
					,@exclude_query_output = 1
					,@query_result_width = 1000
				    ,@query_result_separator = '	' --tab
                    ,@execute_query_database = 'Report_MMS'
					,@query=@query

     delete #emaildata from #emaildata a join #top1 b on a.CorporateCode = b.CorporateCode
     drop table #top1
     drop table #temp1
end

drop table #emaildata

END


