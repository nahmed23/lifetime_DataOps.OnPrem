


/* ***** This stored procedure is used in the process which sends data files to our Corporate partners detailing the club usage for their employees.
                 This script was updated with Jira REP-8298 in February 2020 to correct the reported junior dues. **** 
				 This script was updated again in March 2020 to include grandfathered Jr dues and fix the email functionality that was failing*/


CREATE PROCEDURE [dbo].[mmsEmailCWUsageReport]
								@RowsProcessed int output, 
								@Description  varchar(80) output
AS 
BEGIN

/* Emails Usage Reports for corporate accounts*/

SET XACT_ABORT ON
SET NOCOUNT    ON
declare @CompanyID varchar(50)
declare @UsageReportMemberType varchar(50)
declare @ReportToEmailAddress varchar(150)
declare @FirstOfLastMonth varchar(150)
declare @FirstOfCurrentMonth varchar(150)
declare @query varchar(8000)
declare @Count int

set @FirstOfLastMonth = convert(varchar,month(dateadd(mm,-1,getdate()))) + '/01/' + convert(varchar,year(dateadd(mm,-1,getdate())))
set @FirstOfCurrentMonth = dateadd(mm,1,@FirstOfLastMonth)

Select CompanyID, CorporateCode, ReportToEmailAddress,UsageReportMemberType
into #emaildata
from   vcompany
where UsageReportFlag = 1
and ReportToEmailAddress is not null 
and ltrim(rtrim(ReportToEmailAddress)) <> ''

DECLARE @subjectline VARCHAR (250)
SET @subjectline = 'Corporate Wellness Club Usage Report'

DECLARE @BodyText VARCHAR(2000)

DECLARE @FileName VARCHAR(50)
SET @FileName = 'ClubUsageReport' + CONVERT(VARCHAR(12),GETDATE(),110) +'.csv'

select @RowsProcessed = count(*) from #emaildata
select @Description = 'Number of Companies that received emails'
while (select count(*) from #emaildata) > 0
begin

   select top 1 CompanyID, ReportToEmailAddress,UsageReportMemberType
   into #top1 
   from #emaildata


   select @CompanyID = CompanyID,
          @ReportToEmailAddress  = ReportToEmailAddress ,
          @UsageReportMemberType = isnull(UsageReportMemberType,'Both') 
   from #top1


      SELECT M.MemberID, M.FirstName, M.LastName,P.Description AS ProductDesc,
             CONVERT( DECIMAL(6,2),MS.CurrentPrice * ( ( ISNULL( tCPTR.SumTaxPercentage, 0 ) * .01 ) + 1 ) ) AS DuesRate,
             ISNULL(JrMember.JrMemberCount,0) * CONVERT( DECIMAL(6,2), ISNULL( JrDues.JrDues, 0 ) ) AS JrDuesRate,
             CONVERT( VARCHAR(10), M.JoinDate, 110 )AS JoinDate,VMS.Description AS MembershipStatus,
             VMT.Description AS MemberType,ISNULL(MU.ClubUsage,0) AS Visits
      into #temp1
      FROM dbo.vMember M JOIN vMembership MS ON M.MembershipID = MS.MembershipID
           JOIN vClub C ON MS.ClubID = C.ClubID
           JOIN vMembershipType MST	ON MS.MembershipTypeID= MST.MembershipTypeID
           JOIN vProduct P ON P.ProductID= MST.ProductID
           JOIN vValMembershipStatus VMS	ON MS.ValMembershipStatusID= VMS.ValMembershipStatusID
           JOIN vValMemberType VMT ON M.ValMemberTypeID= VMT.ValMemberTypeID
           JOIN vClubProduct CP ON MS.ClubID = CP.ClubID
                AND MST.ProductID= CP.ProductID
           LEFT JOIN ( SELECT SUM(isnull(TaxPercentage,0))AS SumTaxPercentage, CPTR.ClubID,CPTR.ProductID
                       FROM vClubProductTaxRate CPTR JOIN vTaxRate TR ON CPTR.TaxRateID = TR.TaxRateID
                       GROUP BY CPTR.ClubID, CPTR.ProductID) tCPTR ON CP.ClubID = tCPTR.ClubID
                                                                    AND	CP.ProductID = tCPTR.ProductID
           LEFT JOIN (SELECT MemberID,COUNT(*) ClubUsage
                        FROM vMemberUsage  
                       WHERE UsageDateTime BETWEEN @FirstOfLastMonth AND @FirstOfCurrentMonth
                       GROUP BY MemberID) AS MU ON MU.MemberID= M.MemberID
           LEFT JOIN (
						-----------Non Grandfathered Jr Dues------------------------------
						SELECT MS.MembershipID ,C.ClubID,PT.ProductID
								,CASE
									WHEN DATEDIFF(MM,M.JoinDate,getdate()) < 1
									THEN (PTP.Price/DAY(EOMONTH(GETDATE())))*DATEDIFF(D,DATEADD(D,-1,M.JoinDate),EOMONTH(GETDATE()))*((isnull(TR.TaxPercentage,0)+100)/100)  --case when prorated jrdues for after tax price
									ELSE PTP.Price*((isnull(TR.TaxPercentage,0)+100)/100) --regular after tax jrdues
								END AS JrDues
						
							FROM vMembershipProductTier MPT
							JOIN vProductTier PT ON PT.ProductTierID = MPT.ProductTierID
							JOIN vMembership MS ON MS.MembershipID=MPT.MembershipID
							JOIN vClub C ON MS.ClubID=C.ClubID
							JOIN vMembershipType MT ON MS.MembershipTypeID=MT.MembershipTypeID
							JOIN vProductTierPrice PTP On PT.ProductTierID = PTP.ProductTierID
							JOIN vValCardLevel CL ON PTP.ValCardLevelID = CL.ValCardLevelID
							JOIN vMembershipAttribute MA ON MA.MembershipID=MS.MembershipID
						
							LEFT JOIN vClubProductTaxRate CPTR ON PT.ProductID = CPTR.ProductID AND C.ClubID = CPTR.ClubID
							LEFT JOIN vTaxRate TR ON CPTR.TaxRateID = TR.TaxRateID
							LEFT JOIN vMember M ON M.MembershipID=MS.MembershipID
							JOIN ( SELECT ClubID,CASE WHEN CHARINDEX(' ',MarketingClubLevel,1) = 0 THEN MarketingClubLevel 
							ELSE SUBSTRING(MarketingClubLevel,1,(CHARINDEX(' ',MarketingClubLevel,1)))
							END AS ClubDescription
							FROM vClub
								) ClubDescription ON ClubDescription.ClubDescription = CL.Description AND ClubDescription.ClubID=C.ClubID
							WHERE M.ValMemberTypeID = 4
									AND M.ActiveFlag = 1
							GROUP BY MS.MembershipID,C.ClubID ,PT.ProductID,PTP.Price, MA.EffectiveThruDateTime, MA.ValMembershipAttributeTypeID,MA.AttributeValue,TR.TaxPercentage,M.JoinDate
							
							UNION
							-----------Grandfathered  to Regular Jr Dues------------------------------
							SELECT MS.MembershipID ,C.ClubID,PT.ProductID
								,CASE
									WHEN DATEDIFF(MM,M.JoinDate,getdate()) < 1
									THEN (PTP.Price/DAY(EOMONTH(GETDATE())))*DATEDIFF(D,DATEADD(D,-1,M.JoinDate),EOMONTH(GETDATE()))*((isnull(TR.TaxPercentage,0)+100)/100)  --case when prorated jrdues for after tax price
									ELSE PTP.Price*((isnull(TR.TaxPercentage,0)+100)/100) --regular after tax jrdues
								END AS JrDues
						
							 FROM vMembership MS
							JOIN vMembershipAttribute MA
							ON MA.MembershipID=MS.MembershipID
							JOIN vMember M
							ON M.MembershipID=MA.MembershipID
							JOIN vClubProductTier CPT
							ON CPT.ClubID=MS.ClubID
							JOIN vProductTierPrice PTP
							ON PTP.ProductTierID=CPT.ProductTierID
							JOIN vProductTier PT
							ON PT.ProductTierID=PTP.ProductTierID
							JOIN vMembershipType MT
							ON MT.MembershipTypeID=MS.MembershipTypeID
							JOIN vClub C
							ON C.ClubID=MS.ClubID
							JOIN vValCardLevel CL
							ON CL.ValCardLevelID=PTP.ValCardLevelID
							LEFT JOIN vClubProductTaxRate CPTR ON PT.ProductID = CPTR.ProductID AND C.ClubID = CPTR.ClubID
							LEFT JOIN vTaxRate TR ON CPTR.TaxRateID = TR.TaxRateID
							JOIN ( SELECT ClubID,CASE WHEN CHARINDEX(' ',MarketingClubLevel,1) = 0 THEN MarketingClubLevel   --adding a join to select a single jrdues price when there are multiple pricing tiers associated with a valcardlevelID
							ELSE SUBSTRING(MarketingClubLevel,1,(CHARINDEX(' ',MarketingClubLevel,1)))
							END AS ClubDescription
							FROM vClub
								) ClubDescription ON ClubDescription.ClubDescription = CL.Description AND ClubDescription.ClubID=C.ClubID

							WHERE MA.ValMembershipAttributeTypeID = 15
							AND (MA.EffectiveThruDateTime IS NOT NULL OR MA.EffectiveThruDateTime <= GETDATE())
							AND MA.MembershipID NOT IN 
							(
							SELECT MembershipID FROM vMembershipProductTier
							)
							AND M.ActiveFlag = 1
							AND M.ValMemberTypeID = 4
							AND PT.ValProductTierTypeID = 2
							GROUP BY MS.MembershipID,C.ClubID ,PT.ProductID,PTP.Price, MA.EffectiveThruDateTime, MA.ValMembershipAttributeTypeID,MA.AttributeValue,TR.TaxPercentage,M.JoinDate

							UNION
							----------------------Grandfathered Jr Dues----------------------------
							SELECT MS.MembershipID ,C.ClubID,PT.ProductID
								,CASE
									WHEN DATEDIFF(MM,M.JoinDate,getdate()) < 1 AND MA.ValMembershipAttributeTypeID = 15 AND (MA.EffectiveThruDateTime >= GETDATE() OR MA.EffectiveThruDateTime IS NULL) -- Case when when prorated grandfathered jr dues after tax
									THEN (CONVERT(DECIMAL(6,2),MA.AttributeValue)/DAY(EOMONTH(GETDATE())))*DATEDIFF(D,DATEADD(D,-1,M.JoinDate),EOMONTH(GETDATE()))*((isnull(TR.TaxPercentage,0)+100)/100)
									WHEN (MA.ValMembershipAttributeTypeID = 15 AND (MA.EffectiveThruDateTime >= GETDATE() OR MA.EffectiveThruDateTime IS NULL))
									THEN CONVERT(DECIMAL(6,2),MA.AttributeValue)*((isnull(TR.TaxPercentage,0)+100)/100)
								END AS JrDues
						
							FROM vMembershipAttribute MA
							JOIN vMembership MS
							ON MA.MembershipID=MS.MembershipID
							JOIN vMember M
							ON M.MembershipID=MA.MembershipID
							JOIN vClubProductTier CPT
							ON CPT.ClubID=MS.ClubID
							JOIN vClub C
							ON C.ClubID=MS.ClubID
							JOIN vProductTierPrice PTP
							ON PTP.ProductTierID=CPT.ProductTierID
							JOIN vProductTier PT
							ON PT.ProductTierID=PTP.ProductTierID
							JOIN vMembershipType MT
							ON MT.MembershipTypeID=MS.MembershipTypeID
							JOIN vValCardLevel CL
							ON CL.ValCardLevelID=PTP.ValCardLevelID
							LEFT JOIN vClubProductTaxRate CPTR ON PT.ProductID = CPTR.ProductID AND C.ClubID = CPTR.ClubID
							LEFT JOIN vTaxRate TR ON CPTR.TaxRateID = TR.TaxRateID
							JOIN ( SELECT ClubID,CASE WHEN CHARINDEX(' ',MarketingClubLevel,1) = 0 THEN MarketingClubLevel   --adding a join to select a single jrdues price when there are multiple pricing tiers associated with a valcardlevelID
							ELSE SUBSTRING(MarketingClubLevel,1,(CHARINDEX(' ',MarketingClubLevel,1)))
							END AS ClubDescription
							FROM vClub
								) ClubDescription ON ClubDescription.ClubDescription = CL.Description AND ClubDescription.ClubID=C.ClubID
							WHERE M.ValMemberTypeID = 4
							AND M.ActiveFlag = 1
							AND MA.ValMembershipAttributeTypeID = 15
							 AND (MA.EffectiveThruDateTime >= GETDATE() OR MA.EffectiveThruDateTime IS NULL)
							GROUP BY MS.MembershipID,C.ClubID ,PT.ProductID, MA.EffectiveThruDateTime, MA.ValMembershipAttributeTypeID,MA.AttributeValue,TR.TaxPercentage,M.JoinDate, PTP.ProductTierID
							
								)
								JrDues ON MS.ClubID = JrDues.ClubID
                                                                               AND MS.JrMemberDuesProductID= JrDues.ProductID
																			   AND MS.MembershipID=JrDues.MembershipID
                                                                               AND C.AssessJrMemberDuesFlag= 1
                                                                               AND( MST.AssessJrMemberDuesFlag = 1 OR MST.AssessJrMemberDuesFlag IS NULL )
            LEFT JOIN (SELECT MembershipID,Count(*) JrMemberCount
                         FROM vMember 
                        WHERE ValMemberTypeID= 4	
													AND (AssessJrMemberDuesFlag = 1 OR AssessJrMemberDuesFlag IS NULL)
                          AND ActiveFlag= 1
                         GROUP BY MembershipID) JrMember ON MS.MembershipID= JrMember.MembershipID	
	WHERE VMS.Description IN ( 'Active', 'Pending Termination' ) AND( MS.ExpirationDate IS NULL	OR MS.ExpirationDate>= @FirstOfLastMonth  )
	      AND	M.ActiveFlag = 1
	      AND	MS.CompanyID =  convert(varchar,@CompanyID)
	      AND CP.ClubID= MS.ClubID
	      AND CASE WHEN 'Both' = @UsageReportMemberType AND VMT.Description IN ('Primary', 'Partner') THEN 'Both' ELSE VMT.Description END = @UsageReportMemberType
	GROUP BY M.MemberID, M.FirstName,M.LastName,M.JoinDate,VMT.Description,P.Description,VMS.Description,MS.CurrentPrice,JrDues.JrDues,tCPTR.sumTaxPercentage,MU.ClubUsage,JrMember.JrMemberCount

    select @Count = Count(*) from #temp1

    SET @BodyText = 'A Corporate Usage Report is included as an attachment to this email. If the attached report can not be accessed or if it has been removed from this email, please contact your email support administrator for instructions to allow receipt of external attachments.  Additions and/or removals need to be requested via the Request for Change form and submitted by the 20th of this month. A total of '+ convert(varchar,@count) + ' members were processed for the period of ' + convert(varchar,@FirstOfLastMonth,110)+ ' to ' +  convert(varchar,dateadd(dd,-1,@FirstOfCurrentMonth),110)  + '. Expand columns to view full column contents.  Do not reply to this email.  Contact your Life Time Fitness Client Services Specialist with questions.'

	set @query = 'SELECT M.MemberID, M.FirstName, M.LastName,P.Description AS ProductDesc, CONVERT( DECIMAL(6,2),MS.CurrentPrice * ((ISNULL(tCPTR.SumTaxPercentage,0)*.01)+1)) AS DuesRate, ISNULL(JrMember.JrMemberCount,0) * CONVERT( DECIMAL(6,2), ISNULL( JrDues.JrDues, 0 ) ) AS JrDuesRate, CONVERT( VARCHAR(10), M.JoinDate, 110 )AS JoinDate,VMS.Description AS MembershipStatus, VMT.Description AS MemberType,ISNULL(MU.ClubUsage,0) AS Visits
	           FROM dbo.vMember M JOIN vMembership MS ON M.MembershipID = MS.MembershipID
	                   JOIN vClub C ON MS.ClubID = C.ClubID
	                   JOIN vMembershipType MST	ON MS.MembershipTypeID= MST.MembershipTypeID
	                   JOIN vProduct P ON P.ProductID= MST.ProductID
	                   JOIN vValMembershipStatus VMS ON MS.ValMembershipStatusID= VMS.ValMembershipStatusID
	                   JOIN vValMemberType VMT ON M.ValMemberTypeID= VMT.ValMemberTypeID
	                   JOIN vClubProduct CP ON MS.ClubID = CP.ClubID AND MST.ProductID= CP.ProductID
	                   LEFT JOIN ( SELECT SUM(isnull(TaxPercentage,0))AS SumTaxPercentage, CPTR.ClubID,CPTR.ProductID FROM vClubProductTaxRate CPTR JOIN vTaxRate TR ON CPTR.TaxRateID = TR.TaxRateID GROUP BY CPTR.ClubID, CPTR.ProductID) tCPTR ON CP.ClubID = tCPTR.ClubID
					LEFT JOIN (SELECT MemberID,COUNT(*) ClubUsage FROM vMemberUsage   WHERE UsageDateTime BETWEEN '''  + @FirstOfLastMonth + '''  AND ''' + @FirstOfCurrentMonth + ''' GROUP BY MemberID) AS MU ON MU.MemberID= M.MemberID
	                LEFT JOIN ( SELECT MS.MembershipID ,C.ClubID,PT.ProductID ,CASE WHEN DATEDIFF(MM,M.JoinDate,getdate()) < 1 THEN (PTP.Price/DAY(EOMONTH(GETDATE())))*DATEDIFF(D,DATEADD(D,-1,M.JoinDate),EOMONTH(GETDATE()))*((isnull(TR.TaxPercentage,0)+100)/100) ELSE PTP.Price*((isnull(TR.TaxPercentage,0)+100)/100) END AS JrDues
							FROM vMembershipProductTier MPT
							JOIN vProductTier PT ON PT.ProductTierID = MPT.ProductTierID
							JOIN vMembership MS ON MS.MembershipID=MPT.MembershipID
							JOIN vClub C ON MS.ClubID=C.ClubID
							JOIN vMembershipType MT ON MS.MembershipTypeID=MT.MembershipTypeID
							JOIN vProductTierPrice PTP On PT.ProductTierID = PTP.ProductTierID
							JOIN vValCardLevel CL ON PTP.ValCardLevelID = CL.ValCardLevelID
							JOIN vMembershipAttribute MA ON MA.MembershipID=MS.MembershipID
							LEFT JOIN vClubProductTaxRate CPTR ON PT.ProductID = CPTR.ProductID AND C.ClubID = CPTR.ClubID
							LEFT JOIN vTaxRate TR ON CPTR.TaxRateID = TR.TaxRateID
							LEFT JOIN vMember M ON M.MembershipID=MS.MembershipID
							JOIN ( SELECT CLUBID,CASE WHEN CHARINDEX('' '',MarketingClubLevel,1) = 0 THEN MarketingClubLevel ELSE SUBSTRING(MarketingClubLevel,1,CHARINDEX('' '',MarketingClubLevel,1)) END AS  ClubDescription FROM vClub ) ClubDescription ON ClubDescription.ClubDescription = CL.Description AND ClubDescription.ClubID=C.ClubID
							WHERE M.ValMemberTypeID = 4 AND M.ActiveFlag = 1
							GROUP BY MS.MembershipID,C.ClubID ,PT.ProductID,PTP.Price, MA.EffectiveThruDateTime, MA.ValMembershipAttributeTypeID,MA.AttributeValue,TR.TaxPercentage,M.JoinDate
							UNION
							SELECT MS.MembershipID ,C.ClubID,PT.ProductID ,CASE WHEN DATEDIFF(MM,M.JoinDate,getdate()) < 1 THEN (PTP.Price/DAY(EOMONTH(GETDATE())))*DATEDIFF(D,DATEADD(D,-1,M.JoinDate),EOMONTH(GETDATE()))*((isnull(TR.TaxPercentage,0)+100)/100) ELSE PTP.Price*((isnull(TR.TaxPercentage,0)+100)/100) END AS JrDues
							FROM vMembership MS
							JOIN vMembershipAttribute MA ON MA.MembershipID=MS.MembershipID
							JOIN vMember M ON M.MembershipID=MA.MembershipID
							JOIN vClubProductTier CPT ON CPT.ClubID=MS.ClubID
							JOIN vProductTierPrice PTP ON PTP.ProductTierID=CPT.ProductTierID
							JOIN vProductTier PT ON PT.ProductTierID=PTP.ProductTierID
							JOIN vMembershipType MT ON MT.MembershipTypeID=MS.MembershipTypeID
							JOIN vClub C ON C.ClubID=MS.ClubID
							JOIN vValCardLevel CL ON CL.ValCardLevelID=PTP.ValCardLevelID
							LEFT JOIN vClubProductTaxRate CPTR ON PT.ProductID = CPTR.ProductID AND C.ClubID = CPTR.ClubID
							LEFT JOIN vTaxRate TR ON CPTR.TaxRateID = TR.TaxRateID
							JOIN (SELECT ClubID,CASE WHEN CHARINDEX('' '',MarketingClubLevel,1) = 0 THEN MarketingClubLevel  ELSE SUBSTRING(MarketingClubLevel,1,(CHARINDEX('' '',MarketingClubLevel,1))) END AS ClubDescription FROM vClub ) ClubDescription ON ClubDescription.ClubDescription = CL.Description AND ClubDescription.ClubID=C.ClubID
							WHERE MA.ValMembershipAttributeTypeID = 15 AND (MA.EffectiveThruDateTime IS NOT NULL OR MA.EffectiveThruDateTime <= GETDATE()) AND MA.MembershipID NOT IN (SELECT MembershipID FROM vMembershipProductTier) AND M.ActiveFlag = 1 AND M.ValMemberTypeID = 4 AND PT.ValProductTierTypeID = 2
							GROUP BY MS.MembershipID,C.ClubID ,PT.ProductID,PTP.Price, MA.EffectiveThruDateTime, MA.ValMembershipAttributeTypeID,MA.AttributeValue,TR.TaxPercentage,M.JoinDate
							UNION
							SELECT MS.MembershipID ,C.ClubID,PT.ProductID ,CASE WHEN DATEDIFF(MM,M.JoinDate,getdate()) < 1 AND MA.ValMembershipAttributeTypeID = 15 AND (MA.EffectiveThruDateTime >= GETDATE() OR MA.EffectiveThruDateTime IS NULL) THEN (CONVERT(DECIMAL(6,2),MA.AttributeValue)/DAY(EOMONTH(GETDATE())))*DATEDIFF(D,DATEADD(D,-1,M.JoinDate),EOMONTH(GETDATE()))*((isnull(TR.TaxPercentage,0)+100)/100)
						WHEN (MA.ValMembershipAttributeTypeID = 15 AND (MA.EffectiveThruDateTime >= GETDATE() OR MA.EffectiveThruDateTime IS NULL)) THEN CONVERT(DECIMAL(6,2),MA.AttributeValue)*((isnull(TR.TaxPercentage,0)+100)/100)
						END AS JrDues
							FROM vMembershipAttribute MA
							JOIN vMembership MS ON MA.MembershipID=MS.MembershipID
							JOIN vMember M ON M.MembershipID=MA.MembershipID
							JOIN vClubProductTier CPT ON CPT.ClubID=MS.ClubID
							JOIN vClub C ON C.ClubID=MS.ClubID
							JOIN vProductTierPrice PTP ON PTP.ProductTierID=CPT.ProductTierID
							JOIN vProductTier PT ON PT.ProductTierID=PTP.ProductTierID
							JOIN vMembershipType MT ON MT.MembershipTypeID=MS.MembershipTypeID
							JOIN vValCardLevel CL ON CL.ValCardLevelID=PTP.ValCardLevelID
							LEFT JOIN vClubProductTaxRate CPTR ON PT.ProductID = CPTR.ProductID AND C.ClubID = CPTR.ClubID
							LEFT JOIN vTaxRate TR ON CPTR.TaxRateID = TR.TaxRateID
							JOIN ( SELECT ClubID,CASE WHEN CHARINDEX('' '',MarketingClubLevel,1) = 0 THEN MarketingClubLevel ELSE SUBSTRING(MarketingClubLevel,1,(CHARINDEX('' '',MarketingClubLevel,1))) END AS ClubDescription FROM vClub ) ClubDescription ON ClubDescription.ClubDescription = CL.Description AND ClubDescription.ClubID=C.ClubID
							WHERE M.ValMemberTypeID = 4 AND M.ActiveFlag = 1 AND MA.ValMembershipAttributeTypeID = 15 AND (MA.EffectiveThruDateTime >= GETDATE() OR MA.EffectiveThruDateTime IS NULL)
							GROUP BY MS.MembershipID,C.ClubID ,PT.ProductID, MA.EffectiveThruDateTime, MA.ValMembershipAttributeTypeID,MA.AttributeValue,TR.TaxPercentage,M.JoinDate, PTP.ProductTierID ) JrDues ON MS.ClubID = JrDues.ClubID AND MS.JrMemberDuesProductID= JrDues.ProductID AND MS.MembershipID=JrDues.MembershipID AND C.AssessJrMemberDuesFlag= 1  AND( MST.AssessJrMemberDuesFlag = 1 OR MST.AssessJrMemberDuesFlag IS NULL )
	                    LEFT JOIN (SELECT MembershipID,Count(*) JrMemberCount FROM vMember WHERE ValMemberTypeID= 4 AND (AssessJrMemberDuesFlag = 1 OR AssessJrMemberDuesFlag IS NULL) AND ActiveFlag= 1 GROUP BY MembershipID) JrMember ON MS.MembershipID= JrMember.MembershipID AND	CP.ProductID = tCPTR.ProductID WHERE  VMS.Description IN ( ''Active'', ''Pending Termination'' ) AND( MS.ExpirationDate IS NULL	OR MS.ExpirationDate>= ''' + @FirstOfLastMonth + ''' ) AND	M.ActiveFlag = 1 AND	MS.CompanyID = ' + @CompanyID + ' AND CP.ClubID= MS.ClubID AND CASE WHEN ''Both'' = ''' + @UsageReportMemberType + ''' AND VMT.Description IN (''Primary'', ''Partner'') THEN ''Both'' ELSE VMT.Description END = ''' + @UsageReportMemberType + ''' GROUP BY M.MemberID, M.FirstName,M.LastName,M.JoinDate,VMT.Description,P.Description,VMS.Description,MS.CurrentPrice,JrDues.JrDues,tCPTR.sumTaxPercentage,MU.ClubUsage,JrMember.JrMemberCount			'
    
    
      EXEC msdb.dbo.sp_send_dbmail 
					 @profile_name = 'LifeTime'
                    ,@recipients = @ReportToEmailAddress
				--	,@copy_recipients = 'ITDatabase@lifetimefitness.com'
                    ,@subject=@subjectline
                    ,@body = @BodyText
					,@attach_query_result_as_file = 1
					,@query_attachment_filename = @FileName
					,@exclude_query_output = 1
					,@query_result_width = 1000
				    ,@query_result_separator = '	' --tab
                    ,@execute_query_database = 'Report_MMS'
					,@query=@query

    delete #emaildata from #emaildata a join #top1 b on a.CompanyID = b.CompanyID
    drop table #top1
    drop table #temp1
END

  drop table #emaildata
END




