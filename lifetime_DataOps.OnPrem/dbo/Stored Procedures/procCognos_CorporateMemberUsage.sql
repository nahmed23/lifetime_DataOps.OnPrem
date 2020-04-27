



-----  Sample execution
--- Exec procCognos_CorporateMemberUsage '4/1/2015','4/10/2015','13125','Primary','All Members','Advanta Format'
-----



CREATE PROC [dbo].[procCognos_CorporateMemberUsage] (
    @StartDate DATETIME,
    @EndDate DATETIME,
    @CompanyIDList VARCHAR(8000),
    @MemberTypeList VARCHAR(100),
	@PartnerProgramEnrollment  VARCHAR(50),
	@ReportType VARCHAR(100)
)

AS
BEGIN 
SET XACT_ABORT ON
SET NOCOUNT ON

IF 1=0 BEGIN
       SET FMTONLY OFF
     END
SET @StartDate = CASE WHEN @StartDate = 'Jan 1, 1900' THEN DATEADD(MONTH,DATEDIFF(MONTH,0,GETDATE()-1),0) ELSE @StartDate END
SET @EndDate = CASE WHEN @EndDate = 'Jan 1, 1900' THEN CONVERT(DATETIME,CONVERT(VARCHAR,GETDATE()-1,101),101) ELSE @EndDate END

DECLARE @AdjEndDate DATETIME
DECLARE @ReportRunDateTime AS DATETIME
SET @AdjEndDate = DateAdd(Day,1,@EndDate)  ----- to return the full final day of the period
SET @ReportRunDateTime = Replace(Substring(convert(varchar,getdate(),100),1,6)+', '+Substring(convert(varchar,GETDATE(),100),8,10)+' '+Substring(convert(varchar,getdate(),100),18,2),'  ',' ')

DECLARE @HeaderDateRange Varchar(110)
SET @HeaderDateRange = Replace(Substring(convert(varchar,@StartDate,100),1,6)+', '+Substring(convert(varchar,@StartDate,100),8,4),'  ',' ')
                       + ' through ' + 
                       Replace(Substring(convert(varchar,@EndDate,100),1,6)+', '+Substring(convert(varchar,@EndDate,100),8,4),'  ',' ')

CREATE TABLE #tmpList (StringField VARCHAR(50))
  
CREATE TABLE #MemberType (MemberDescription VARCHAR(50))
EXEC procParseStringList @MemberTypeList
INSERT INTO #MemberType (MemberDescription) SELECT StringField FROM #tmpList
TRUNCATE TABLE #tmpList
  
CREATE TABLE #Company (CompanyID VARCHAR(50))
IF @CompanyIDList <> '0'
  BEGIN
    EXEC procParseStringList @CompanyIDList
    INSERT INTO #Company (CompanyID) SELECT StringField FROM #tmpList
  END
ELSE
  BEGIN
    INSERT INTO #Company VALUES('0') 
  END


   --- Gather list of all memberships with selected corporate affiliation - Membership Company or Reimbursement Program Company
Select M.MembershipID, M.MemberID, #C.CompanyID
INTO #CompanyMembers
From vMember M
Join vValMemberType VMT
  On M.ValMemberTypeID = VMT.ValMemberTypeID
JOIN #MemberType #MT
  On VMT.Description = #MT.MemberDescription
Join vMemberReimbursement MR
  On M.MemberID = MR.MemberID
Join vReimbursementProgram RP
  On MR.ReimbursementProgramID = RP.ReimbursementProgramID
Join vCompany CO
  On RP.CompanyID = CO.CompanyID
Join vMembership MS
  On M.MembershipID = MS.MembershipID
JOIN vValMembershipStatus VMS
    ON MS.ValMembershipStatusID = VMS.ValMembershipStatusID
JOIN #Company #C
  ON (Convert(varchar,CO.CompanyID) = Convert(Varchar,#C.CompanyID)
    OR #C.CompanyID = '0')
Where MR.EnrollmentDate <= @EndDate 
  AND (MR.TerminationDate > @StartDate OR ISNull(MR.TerminationDate,'1/1/1900')='1/1/1900')   
  AND (MS.ExpirationDate > @StartDate OR ISNull(MS.ExpirationDate,'1/1/1900')='1/1/1900') 
  AND M.ActiveFlag = 1
  AND VMS.Description IN ('Active', 'Pending Termination','Terminated')



UNION

  Select MS.MembershipID,M.MemberID, #C.CompanyID
  From vMember M
  Join vValMemberType VMT
    On M.ValMemberTypeID = VMT.ValMemberTypeID
  JOIN #MemberType #MT
    On VMT.Description = #MT.MemberDescription
  Join vMembership MS WITH (NOLOCK)
    On M.MembershipID = MS.MembershipID
  JOIN vValMembershipStatus VMS
    ON MS.ValMembershipStatusID = VMS.ValMembershipStatusID
  Join vCompany CO
    ON MS.CompanyID = CO.CompanyID
  JOIN #Company #C
    ON (Convert(varchar,CO.CompanyID) = Convert(Varchar,#C.CompanyID)
    OR #C.CompanyID = '0')
 WHERE (MS.ExpirationDate > @StartDate OR ISNull(MS.ExpirationDate,'1/1/1900')='1/1/1900') 
   AND VMS.Description IN ('Active', 'Pending Termination','Terminated')
   AND M.ActiveFlag = 1



 Select MembershipID
INTO #CompanyMemberships
 From #CompanyMembers
   Group By MembershipID



  ---- Gather all the membership information 
SELECT Membership.MembershipID,
       Membership.ClubID,
       Membership.CompanyID,
       Membership.CancellationRequestDate,
       Membership.ExpirationDate,
       Membership.MembershipTypeID,
       Membership.ValMembershipStatusID,
       Membership.QualifiedSalesPromotionID,
       ValMembershipStatus.Description MembershipStatusDescription,
       Membership.ClubID OriginalMembershipClubID,
       Membership.JrmemberDuesproductID       
  INTO #Membership
  FROM vMembership Membership WITH (NOLOCK)
  JOIN #CompanyMemberships #CM
    ON Membership.MembershipID = #CM.MembershipID
  JOIN vValMembershipStatus ValMembershipStatus
    ON Membership.ValMembershipStatusID = ValMembershipStatus.ValMembershipStatusID



 
CREATE INDEX IX_MembershipID ON #Membership(MembershipID)
CREATE INDEX IX_ClubID ON #Membership(ClubID)


  --- Gather all possible dues product tax
SELECT CPPT.ClubID, 
       CPPT.ProductID, 
       SUM((ISNULL(TaxPercentage,0)/100)) TaxRate
  INTO #ClubProductPriceTax
  FROM vClubProductPriceTax CPPT
  JOIN vProduct P 
    ON CPPT.ProductID = P.ProductID
 WHERE P.DepartmentID = 1
 GROUP BY CPPT.ClubID, CPPT.ProductID
 
   --- gather all junior dues prices for the queried memberships
 SELECT MS.MembershipID, 
       COUNT(M.MemberID) NumberOfJuniors,
       SUM(CASE When ((M.AssessJrMemberDuesFlag = 1 or M.AssessJrMemberDuesFlag Is Null)
                      AND 
                       (C.AssessJrMemberDuesFlag = 1 or C.AssessJrMemberDuesFlag Is Null )
                      AND 
                       (MT.AssessJrMemberDuesFlag = 1 or MT.AssessJrMemberDuesFlag Is Null))
                THEN PTP.Price
                ELSE 0
                END ) JrMembershipDues,
       SUM(CASE When ((M.AssessJrMemberDuesFlag = 1 or M.AssessJrMemberDuesFlag Is Null)
                      AND 
                       (C.AssessJrMemberDuesFlag = 1 or C.AssessJrMemberDuesFlag Is Null )
                      AND 
                       (MT.AssessJrMemberDuesFlag = 1 or MT.AssessJrMemberDuesFlag Is Null))
                 THEN CPPT.TaxRate * PTP.Price
                 ELSE 0
                 END) JrMembershipDuesTax
  INTO #JuniorMemberInfo
  FROM #Membership MS
  Join vMembershipProductTier MPT
    ON MS.MembershipID = MPT.MembershipID
  Join vProductTier  PT
    ON MPT.ProductTierID = PT.ProductTierID  
  Join vProductTierPrice PTP
    ON PT.ProductTierID = PTP.ProductTierID
  JOIN vMembershipType MT
    ON MS.MembershipTypeID = MT.MembershipTypeID
  JOIN vValMembershipTypeGroup VMTG
    ON PTP.ValMembershipTypeGroupID= VMTG.ValMembershipTypeGroupID
    AND MT.ValMembershipTypeGroupID = VMTG.ValMembershipTypeGroupID
  Join vClub C
    ON MS.ClubID = C.ClubID
  JOIN vMember M
    ON MS.MembershipID = M.MembershipID
  LEFT JOIN #ClubProductPriceTax CPPT
    ON MS.OriginalMembershipClubID = CPPT.ClubID
   AND MS.JrMemberDuesProductID = CPPT.ProductID
 WHERE M.ValMemberTypeID = 4
   AND M.ActiveFlag = 1
   AND PT.ValProductTierTypeID = 1
 GROUP BY MS.MembershipID

 --- Gather bulk of report data
SELECT MS.CancellationRequestDate, 
       CO.CompanyName,
       VR.Description AS RegionDescription, 
       C.ClubName,
       M.MemberID, 
       M.FirstName, 
       M.LastName, 
       M.JoinDate as JoinDate_Sort,
       Replace(Substring(convert(varchar,M.JoinDate,100),1,6)+', '+Substring(convert(varchar,M.JoinDate,100),8,4),'  ',' ') JoinDate,
       VMS.Description as MembershipStatusDescription, 
       CO.AccountRepInitials, 
       MS.ExpirationDate, 
       CO.CompanyID, 
       P.Description AS ProductDescription, 
       VMT.Description AS MemberTypeDescription, 
       MS.MembershipID, 
       IsNull(MU.UsageDateTime,'Jan 1,1900') AS UsageDateTime,
	   Substring(Convert(Varchar,IsNull(MU.UsageDateTime,'Jan 1,1900'),110),1,10) as UsageDate,
       NULL PromotionName, 
       MS.CurrentPrice  AS MembershipDuesPrice,
       ISNULL(#JuniorMemberInfo.JrMembershipDues,0) JrMembershipDues,
       (CPPT1.TaxRate * IsNull(MS.CurrentPrice,0)) + ISNULL(#JuniorMemberInfo.JrMembershipDuesTax,0) TaxAmount,
       Substring(Convert(Varchar,DOB,110),1,5) BirthDate,
	   M.DOB,
       UC.ClubName AS CheckInClub,
	   UC.ClubID as CheckInClubID,
       MA.AddressLine1,
       MA.AddressLine2,
       MA.City,
       VS.Abbreviation as StateAbbr,
       MA.Zip as ZipCode,
       CASE WHEN DateDiff(day,M.JoinDate,@EndDate) < 8
            THEN 'Y'
            ELSE 'N'
            END MemberJoinedThisWeek
INTO #Results
  FROM #CompanyMembers #CM
  Join vMember M
    ON M.MemberID = #CM.MemberID
  Join vMembership MS
    ON M.MembershipID = MS.MembershipID
  Join vClub C
    ON MS.ClubID = C.ClubID
  JOIN vValRegion VR
    ON VR.ValRegionID = C.ValRegionID
  JOIN vCompany CO
    ON #CM.CompanyID = CO.CompanyID
  Left JOIN vMembershipType MST
    ON MS.MembershipTypeID = MST.MembershipTypeID
  Left JOIN vProduct P
    ON P.ProductID = MST.ProductID
  JOIN vValMemberType VMT
    ON M.ValMemberTypeID = VMT.ValMemberTypeID
  JOIN vMembershipAddress MA
    ON MS.MembershipID = MA.MembershipID
  JOIN vValState VS
    ON MA.ValStateID = VS.ValStateID
  JOIN vValMembershipStatus VMS
    ON MS.ValMembershipStatusID = VMS.ValMembershipStatusID
  LEFT JOIN dbo.vMemberUsage MU
    ON MU.MemberID = M.MemberID 
   AND MU.UsageDateTime >= @StartDate 
   AND MU.UsageDateTime < @AdjEndDate
  LEFT JOIN vClub UC
    ON MU.ClubID = UC.ClubID
  LEFT JOIN #ClubProductPriceTax CPPT1
    ON MST.ProductID = CPPT1.ProductID
   AND MS.ClubID = CPPT1.ClubID
  LEFT JOIN #JuniorMemberInfo
    ON MS.MembershipID = #JuniorMemberInfo.MembershipID




   
   
   CREATE TABLE #LastPartnerProgamVersionInPeriod (
   MemberID INT,
   ReimbursementProgramID INT,
   ReimbursementProgramName VARCHAR(50),
   MemberReimbursementID INT
   )
   
   INSERT INTO #LastPartnerProgamVersionInPeriod
   SELECT MR.MemberID,
       RP.ReimbursementProgramID,
       RP.ReimbursementProgramName,
       MAX(MR.MemberReimbursementID)
  FROM #CompanyMembers #CM
  JOIN vMemberReimbursement MR
    ON #CM.MemberID = MR.MemberID
   AND (MR.EnrollmentDate <= @EndDate)
   AND (MR.TerminationDate > @StartDate OR ISNull(MR.TerminationDate,'1/1/1900')='1/1/1900')
  JOIN vReimbursementProgram RP
    ON MR.ReimbursementProgramID = RP.ReimbursementProgramID
  JOIN #Company #C
    ON (Convert(varchar,RP.CompanyID) = Convert(Varchar,#C.CompanyID)
    OR #C.CompanyID = '0')
 GROUP BY MR.MemberID, 
          RP.ReimbursementProgramID, 
          RP.ReimbursementProgramName 



CREATE TABLE #HealthPartnerIDs (
MemberID INT, 
ReimbursementProgramID INT,
ReimbursementProgramName VARCHAR(50),
HealthPartnerID VARCHAR(303),
Part1FieldName VARCHAR(50),
Part1Value VARCHAR(100),
Part2FieldName VARCHAR(50),
Part2Value VARCHAR(100),
Part3FieldName VARCHAR(50),
Part3Value VARCHAR(100),
ProgramTerminationDate Datetime)



INSERT INTO #HealthPartnerIDs
SELECT #LastPartnerProgamVersionInPeriod.MemberID,
       RP.ReimbursementProgramID,
       RP.ReimbursementProgramName,
       STUFF((SELECT ' ' + MRPIP.PartValue
                FROM vMemberReimbursementProgramIdentifierPart MRPIP
                JOIN vReimbursementProgramIdentifierFormatPart RPIFP
                  ON MRPIP.ReimbursementProgramIdentifierFormatPartID = RPIFP.ReimbursementProgramIdentifierFormatPartID
               WHERE MR.MemberReimbursementID = MRPIP.MemberReimbursementID
               ORDER BY RPIFP.FieldSequence
               FOR XML PATH('')),1,1,'') AS HealthPartnerID,
       MAX(CASE WHEN RPIFP.FieldSequence = 1 THEN RPIFP.FieldName ELSE '' END) Part1FieldName,
       MAX(CASE WHEN RPIFP.FieldSequence = 1 THEN MRPIP.PartValue ELSE '' END) Part1Value,
       MAX(CASE WHEN RPIFP.FieldSequence = 2 THEN RPIFP.FieldName ELSE '' END) Part2FieldName,
       MAX(CASE WHEN RPIFP.FieldSequence = 2 THEN MRPIP.PartValue ELSE '' END) Part2Value,
       MAX(CASE WHEN RPIFP.FieldSequence = 3 THEN RPIFP.FieldName ELSE '' END) Part3FieldName,
       MAX(CASE WHEN RPIFP.FieldSequence = 3 THEN MRPIP.PartValue ELSE '' END) Part3Value,
       MR.TerminationDate AS  ProgramTerminationDate
  FROM #LastPartnerProgamVersionInPeriod
  JOIN vMemberReimbursement MR
    ON #LastPartnerProgamVersionInPeriod.MemberReimbursementID = MR.MemberReimbursementID
  JOIN vReimbursementProgram RP
    ON MR.ReimbursementProgramID = RP.ReimbursementProgramID
  JOIN vMemberReimbursementProgramIdentifierPart MRPIP
    ON MR.MemberReimbursementID = MRPIP.MemberReimbursementID
  JOIN vReimbursementProgramIdentifierFormatPart RPIFP
    ON MRPIP.ReimbursementProgramIdentifierFormatPartID = RPIFP.ReimbursementProgramIdentifierFormatPartID
Group By #LastPartnerProgamVersionInPeriod.MemberID,
       RP.ReimbursementProgramID,
       RP.ReimbursementProgramName,
       MR.TerminationDate,
       MR.MemberReimbursementID
 

SELECT DISTINCT MemberID
  INTO #ResultsDistinctMemberIDs
  FROM #Results

Select MemberID, 
  CASE When MAX(UsageDate) = '01-01-1900'
  Then 0
  Else Count(Distinct(UsageDate)) 
  END VisitDays
  INTO #MemberVisitDays
  From #Results
  Group By MemberID


DECLARE @FirstOfMonthAfterEndMonth DATETIME
DECLARE @SecondOfMonthAfterEndMonth DATETIME
DECLARE @FirstOfStartMonth DATETIME
DECLARE @SecondOfStartMonth DATETIME

SET @FirstOfMonthAfterEndMonth = (Select CalendarNextMonthStartingDate from ReportDimDate where CalendarDate = @EndDate) 
SET @SecondOfMonthAfterEndMonth = @FirstOfMonthAfterEndMonth + 1
SET @FirstOfStartMonth = (Select CalendarMonthStartingDate from ReportDimDate where CalendarDate = @StartDate) 
SET @SecondOfStartMonth = @FirstOfStartMonth + 1

DECLARE @HeaderDuesCreditDateRange Varchar(110)
SET @HeaderDuesCreditDateRange = Replace(Substring(convert(varchar,@SecondOfStartMonth,100),1,6)+', '+Substring(convert(varchar,@SecondOfStartMonth,100),8,4),'  ',' ')
                       + ' through ' + 
                       Replace(Substring(convert(varchar,@SecondOfMonthAfterEndMonth,100),1,6)+', '+Substring(convert(varchar,@SecondOfMonthAfterEndMonth,100),8,4),'  ',' ')



CREATE TABLE #DuesCredits (
MemberID INT, 
CalculatedDuesCredit DECIMAL(12,2), 
PartnerSpecificDuesCredit DECIMAL(12,2))


 ---- this data is returned for the Invoice Partner Companies version of the report 
INSERT INTO #DuesCredits           
SELECT DISTINCT OuterMMSTran.MemberID,
                SUM(CASE WHEN ReasonCodeID = 211 THEN (POSAmount + TranAmount) ELSE 0 END) CalculatedDuesCredit,
                SUM(CASE WHEN ReasonCodeID = 210 THEN (POSAmount + TranAmount) ELSE 0 END) PartnerSpecificDuesCredit
  FROM #ResultsDistinctMemberIDs
  JOIN vMMSTran OuterMMSTran
    ON #ResultsDistinctMemberIDs.MemberID = OuterMMSTran.MemberID
 WHERE ReasonCodeID in (211,210)
   AND PostDateTime >= @SecondOfStartMonth
   AND PostDateTime < @SecondOfMonthAfterEndMonth
GROUP BY OuterMMSTran.MemberID




SELECT 
       #Results.CompanyName,
	   #Results.RegionDescription,
       #Results.ClubName,
       #Results.MemberID,
       #Results.FirstName,
       #Results.LastName,
       #Results.JoinDate_Sort,
       #Results.JoinDate,
       #Results.MembershipStatusDescription,
       #Results.ExpirationDate AS MembershipExpirationDate,
       #Results.ProductDescription,
       #Results.MemberTypeDescription,
       #Results.UsageDateTime,
	   #MemberVisitDays.VisitDays as TotalMemberVisitDays,
       #Results.PromotionName,
       #Results.MembershipDuesPrice,
       #Results.JrMembershipDues,
       #Results.TaxAmount,
       #Results.BirthDate,
	   #Results.DOB,
       #HealthPartnerIDs.ReimbursementProgramName,
       #HealthPartnerIDs.HealthPartnerID,
       #HealthPartnerIDs.Part1FieldName,
       #HealthPartnerIDs.Part1Value,
       #HealthPartnerIDs.Part2FieldName,
       #HealthPartnerIDs.Part2Value,
       #HealthPartnerIDs.Part3FieldName,
       #HealthPartnerIDs.Part3Value,
       ABS(#DuesCredits.PartnerSpecificDuesCredit) AS PartnerSpecificDuesCredit,
       ABS(#DuesCredits.CalculatedDuesCredit)AS CalculatedDuesCredit,
       @HeaderDateRange HeaderDateRange,
       #HealthPartnerIDs.ProgramTerminationDate,
       #Results.CheckInClub,
	   #Results.CheckInClubID,
       #Results.AddressLine1,
       #Results.AddressLine2,
       #Results.City,
       #Results.StateAbbr,
       #Results.ZipCode, 
       #Results.MemberJoinedThisWeek,
	   @ReportRunDateTime as ReportRunDateTime,
	   @ReportType as ReportType,
	   @HeaderDuesCreditDateRange as HeaderDuesCreditDateRange,
	   #Results.MembershipID
  FROM #Results
  LEFT JOIN #HealthPartnerIDs
    ON #Results.MemberID = #HealthPartnerIDs.MemberID
  LEFT JOIN #DuesCredits
    ON #Results.MemberID = #DuesCredits.MemberID
  LEFT Join #MemberVisitDays
    ON #Results.MemberID = #MemberVisitDays.MemberID
	Where (@PartnerProgramEnrollment = 'All Members'
	         OR
			 (@PartnerProgramEnrollment ='Members without Reimbursement Programs'
			   AND #HealthPartnerIDs.ReimbursementProgramName is null)
			   OR 
			   (@PartnerProgramEnrollment ='Members with Reimbursement Programs'
			     AND #HealthPartnerIDs.ReimbursementProgramName is not null ))
	Order by #Results.LastName,#Results.FirstName,#Results.MemberID,#Results.UsageDateTime


DROP TABLE #CompanyMembers
DROP TABLE #CompanyMemberships
DROP TABLE #Company
DROP TABLE #MemberType
DROP TABLE #tmpList
DROP TABLE #ResultsDistinctMemberIDs
DROP TABLE #HealthPartnerIDs
Drop TAble #Membership
DROP TABLE #ClubProductPriceTax
DROP TABLE #JuniorMemberInfo
DROP TABLE #LastPartnerProgamVersionInPeriod
DROP TABLE #DuesCredits
DROP TABLE #Results
DROP TABLE #MemberVisitDays

END











