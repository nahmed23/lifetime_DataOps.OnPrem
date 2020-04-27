

CREATE PROCEDURE [dbo].[mmsEmailAdvisorSignupTotals]
AS 
BEGIN

SET XACT_ABORT ON
SET NOCOUNT    ON

/*Set-up variable to include the current date in the name */
DECLARE @subjectline VARCHAR (250)
SET @subjectline = 'Advisor SignUps by Club ' + CONVERT(VARCHAR(12),GETDATE(),110)

DECLARE @BodyText VARCHAR(100)
SET @BodyText = 'Here are the current totals for SignUps by Advisor by Club for ' + CONVERT(VARCHAR(12),GETDATE(),101)

DECLARE @FileName VARCHAR(50)
SET @FileName = 'Advisor_SignUps_By_Club_' + CONVERT(VARCHAR(12),GETDATE(),110) +'.csv'

DECLARE @Recipients VARCHAR(100)
SET @Recipients = 'beverson@lifetimefitness.com;JMaloney@lifetimefitness.com'

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

SELECT C.CLubID,AdvisorEmployeeID,COUNT(*) MyLTCount 
INTO #MyLTCount
FROM tmpLTFUserIdentity A JOIN vMember B ON A.member_id = B.MemberID
JOIN vMembership C ON B.MembershipID = C.MembershipID
WHERE A.DATE > C.InsertedDateTime and A.DATE <= DATEADD(HH,1,C.InsertedDateTime)
AND CreatedDateTime >= DATEADD(DD, -1*(DATEPART(DD,DATEADD(DD,-1,GETDATE())))+1,CAST(DATEADD(DD,-1,GETDATE()) AS VARCHAR(11))) --First of the Month (from Yesterday)
  AND CreatedDateTime < CAST(GETDATE() AS VARCHAR(11))
GROUP BY C.CLubID,C.AdvisorEmployeeID

SELECT c.ClubID, c.ClubName, vsa.Description Area, e.EmployeeID, e.FirstName + '' '' + e.LastName Employee, 
	   '''' [Primary:],
	   COUNT(DISTINCT m.MemberID) PrimaryJoins, COUNT(DISTINCT m.EmailAddress) PrimaryEmailAddress, 
	   COUNT(DISTINCT CASE WHEN m.MIPUpdatedDateTime IS NOT NULL THEN m.MemberID ELSE NULL END) [PrimaryInterest Profile], 
	   '''' [Partner/Secondary:],
	   COUNT(m2.MemberID) PartnerJoins, COUNT(m2.EmailAddress) PartnerEmailAddress, 
	   COUNT(DISTINCT CASE WHEN m2.MIPUpdatedDateTime IS NOT NULL THEN m2.MemberID ELSE NULL END) [PartnerInterest Profile]
into #EmployeeCounts
FROM vMembership ms
JOIN vEmployee e
  ON e.EmployeeID = ms.AdvisorEmployeeID
JOIN vClub c
  ON c.ClubID = ms.ClubID
JOIN vValSalesArea vsa
  ON vsa.ValSalesAreaID = c.ValSalesAreaID
JOIN vMember m
  ON m.MembershipID = ms.MembershipID
LEFT JOIN vMember m2
  ON (m2.MembershipID = ms.MembershipID AND m2.ValMemberTypeID IN (2,3) AND m2.ActiveFlag = 1) --Partner/Secondary
WHERE CreatedDateTime >= DATEADD(DD, -1*(DATEPART(DD,DATEADD(DD,-1,GETDATE())))+1,CAST(DATEADD(DD,-1,GETDATE()) AS VARCHAR(11))) --First of the Month (from Yesterday)
  AND CreatedDateTime < CAST(GETDATE() AS VARCHAR(11))
  AND ms.ValMembershipStatusID <> 1
  AND m.ValMemberTypeID = 1
  AND e.EmployeeID <> 826
GROUP BY c.ClubID, c.ClubName, vsa.Description, e.EmployeeID, e.FirstName, e.LastName
ORDER BY  e.EmployeeID

SELECT EC.ClubID,EC.ClubName,Area,EmployeeID,Employee,[Primary:],PrimaryJoins Joins
       ,PrimaryEmailAddress EmailAddress,[PrimaryInterest Profile] [Interest Profile], [Partner/Secondary:],PartnerJoins Joins,PartnerEmailAddress EmailAddress, [PartnerInterest Profile] [Interest Profile],isnull(MLC.MyLTCount,0) MyLTUpdatesCount
FROM #EmployeeCounts EC
left join #MyLTCount mlc on EC.clubid = mlc.clubid and EC.EmployeeID = mlc.AdvisorEmployeeID


drop table #MyLTCount
drop table #EmployeeCounts

SET ANSI_WARNINGS ON
SET NOCOUNT OFF
'

END

