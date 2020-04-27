





CREATE PROC [dbo].[procCognos_CorporateMembershipList] (
    @CompanyIDList VARCHAR(8000),
	@RegionList VARCHAR(8000),
    @ClubIDList VARCHAR(8000),
	@MembershipTypeProductIDList VARCHAR(8000)
)

----- Sample Execution
--- Exec procCognos_CorporateMembershipList '18848|17226|18292|16830|17305|19118','All Regions','All Clubs','0'
-----

AS
BEGIN 
SET XACT_ABORT ON
SET NOCOUNT ON

DECLARE @ReportDate Datetime
SET @ReportDate = GetDate()

DECLARE @ReportRunDateTime VARCHAR(21)
DECLARE @HeaderMembershipStatuses  VARCHAR(100)

SET @ReportRunDateTime = Replace(Substring(convert(varchar,GetDate(),100),1,6)+', '+Substring(convert(varchar,GetDate(),100),8,10)+' '+Substring(convert(varchar,GetDate(),100),18,2),'  ',' ')
SET @HeaderMembershipStatuses = 'Active, Late Activation, Non-Paid, Non-Paid Late Activation, Pending Termination'

CREATE TABLE #tmpList (StringField VARCHAR(50))
CREATE TABLE #CompanyIDList (CompanyID VARCHAR(50))
EXEC procParseStringList @CompanyIDList
INSERT INTO #CompanyIDList (CompanyID) SELECT StringField FROM #tmpList
TRUNCATE TABLE #tmpList

CREATE TABLE #MembershipTypeProductIDList (ProductID VARCHAR(50))
EXEC procParseStringList @MembershipTypeProductIDList 
INSERT INTO #MembershipTypeProductIDList (ProductID) SELECT StringField FROM #tmpList
TRUNCATE TABLE #tmpList

SELECT DISTINCT Club.ClubID as ClubID
  INTO #Clubs
  FROM vClub Club
  JOIN fnParsePipeList(@ClubIDList) MMSClubIDList
    ON Convert(Varchar,Club.ClubID) = MMSClubIDList.Item
    OR @ClubIDList like '%All Clubs%'
  JOIN vValRegion Region
    On Club.ValRegionID = Region.ValRegionID
  JOIN fnParsePipeList(@RegionList) RegionList
    ON Region.Description = RegionList.Item
    OR @RegionList like '%All Regions%'



   --- Gather list of all memberships with selected corporate affiliation - Membership Company or Reimbursement Program Company
   --- within the selected clubs and Membership Types

Select M.MembershipID, MS.MembershipTypeID,MS.CurrentPrice,MS.ValMembershipStatusID,M.MemberID, CO.CompanyID,
MS.ClubID, M.ValMemberTypeID,MS.AdvisorEmployeeID   ---- returns one record for all each member with an active a reimb. program company
INTO #CompanyMembers
From vMember M
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
JOIN #Clubs #Clubs
  ON MS.ClubID = #Clubs.ClubID
JOIN #CompanyIDList #C
  ON (Convert(varchar,CO.CompanyID) = Convert(Varchar,#C.CompanyID)
    OR #C.CompanyID = '0')
JOIN vMembershipType MT
  ON MS.MembershipTypeID = MT.MembershipTypeID
JOIN #MembershipTypeProductIDList #M
  ON (Convert(varchar,MT.ProductID) = Convert(Varchar,#M.ProductID)
    OR #M.ProductID = '0')
Where MR.EnrollmentDate <= @ReportDate 
  AND ISNull(MR.TerminationDate,'1/1/2100') > @ReportDate   
  AND ISNull(MS.ExpirationDate,'1/1/2100')> @ReportDate 
  AND M.ActiveFlag = 1
  AND VMS.Description IN ('Active', 'Late Activation', 'Non-Paid', 'Non-Paid, Late Activation', 'Pending Termination')



UNION    ------ returns primary member for all memberships which have a membership company affiliation

  Select MS.MembershipID,MS.MembershipTypeID,MS.CurrentPrice,MS.ValMembershipStatusID,M.MemberID, CO.CompanyID,
  MS.ClubID,M.ValMemberTypeID,MS.AdvisorEmployeeID
  From vMember M
  Join vMembership MS WITH (NOLOCK)
    On M.MembershipID = MS.MembershipID
  JOIN vValMembershipStatus VMS
    ON MS.ValMembershipStatusID = VMS.ValMembershipStatusID
  Join vCompany CO
    ON MS.CompanyID = CO.CompanyID
  JOIN #Clubs #Clubs
    ON MS.ClubID = #Clubs.ClubID
  JOIN #CompanyIDList #C
    ON (Convert(varchar,CO.CompanyID) = Convert(Varchar,#C.CompanyID)
    OR #C.CompanyID = '0')
  JOIN vMembershipType MT
    ON MS.MembershipTypeID = MT.MembershipTypeID
  JOIN #MembershipTypeProductIDList #M
    ON (Convert(varchar,MT.ProductID) = Convert(Varchar,#M.ProductID)
    OR #M.ProductID = '0')
 WHERE VMS.Description IN ('Active', 'Late Activation', 'Non-Paid', 'Non-Paid, Late Activation', 'Pending Termination')
   AND M.ValMemberTypeID = 1
   AND M.ActiveFlag = 1

   -- Rank is assigned based on ValMemberType order for each Membership to enable selecting just 1 record per membership		
SELECT MembershipID,
       MembershipTypeID,
	   CurrentPrice,
	   ValMembershipStatusID,
       MemberID, 
	   CompanyID,
	   ClubID,
	   ValMemberTypeID,	
	   AdvisorEmployeeID,	
       RANK() OVER (PARTITION BY MembershipID				
                        ORDER BY ValMemberTypeID,MemberID) MembershipMemberRank				
  INTO #CompanyMembershipsRanked				
  FROM #CompanyMembers	



-----  find Club IDs for company memberships
Select ClubID
 INTO #CompanyMembershipClubs
From #CompanyMembershipsRanked
 Group By ClubID

-- total tax percentage for a given product and club 
CREATE TABLE #ClubProductTaxRate (
	ClubID INT, 
	ProductID INT,
	ValTaxTypeID INT, 
	TaxPercentage SMALLMONEY 
	)

INSERT INTO #ClubProductTaxRate 
	SELECT CPTR.ClubID, 
	       CPTR.ProductID,
		   TR.ValTaxTypeID, 
		   Sum(TR.TaxPercentage) AS TaxPercentage 
	FROM vClubProductTaxRate CPTR
	JOIN vTaxRate TR 
	 ON TR.TaxRateID = CPTR.TaxRateID
	JOIN #CompanyMembershipClubs #Clubs
	 ON  CPTR.ClubID = #Clubs.ClubID
	GROUP BY CPTR.ClubID, CPTR.ProductID,TR.ValTaxTypeID


---- calculate Membership Junior dues
Select MPT.MembershipID,
       PT.ProductID, 
	   C.ClubID,
       Sum(PTP.Price)  As MembershipJrDues
INTO #MembershipJuniorDues           
From vMembershipProductTier  MPT
 Join vProductTier PT
   On MPT.ProductTierID = PT.ProductTierID
 Join #CompanyMembershipsRanked MS
   On MPT.MembershipID = MS.MembershipID
 Join vClub C
   On MS.ClubID = C.ClubID
 Join vMembershipType MT
   On MS.MembershipTypeID = MT.MembershipTypeID
 Join vProductTierPrice PTP
   On PT.ProductTierID = PTP.ProductTierID
 Join vValMembershipTypeGroup VMTG
   On PTP.ValMembershipTypeGroupID = VMTG.ValMembershipTypeGroupID
   AND MT.ValMembershipTypeGroupID = VMTG.ValMembershipTypeGroupID
 Join vMember M
   On M.MembershipID = MS.MembershipID
 Where M.ValMemberTypeID = 4
       AND M.ActiveFlag = 1
       AND PT.ValProductTierTypeID = 1 ---- Fun Play dues
       AND (M.AssessJrMemberDuesFlag = 1 or M.AssessJrMemberDuesFlag is null )
       AND (C.AssessJrMemberDuesFlag = 1 or C.AssessJrMemberDuesFlag is null )
       AND (MT.AssessJrMemberDuesFlag = 1 or MT.AssessJrMemberDuesFlag is null )
	   AND MS.MembershipMemberRank = 1
 Group by MPT.MembershipID,PT.ProductID, C.ClubID
 Order by MPT.MembershipID


/********  Foreign Currency Stuff ********/
DECLARE @ReportingCurrencyCode VARCHAR(15)
SET @ReportingCurrencyCode = 
(SELECT CASE WHEN COUNT(DISTINCT C.ValCurrencyCodeID) >=2 
             THEN 'USD' ELSE MAX(VCC.CurrencyCode) 
			 END AS ReportingCurrency
  FROM vClub C 
  JOIN #CompanyMembershipClubs #Clubs
    ON C.ClubID = #Clubs.ClubID 
  JOIN vValCurrencyCode VCC 
    ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID)

CREATE TABLE #PlanRate (PlanRate DECIMAL(14,4), FromCurrencyCode VARCHAR(15), PlanYear INT)
INSERT INTO #PlanRate
SELECT PlanExchangeRate, FromCurrencyCode, PlanYear
FROM PlanExchangeRate
WHERE ToCurrencyCode = @ReportingCurrencyCode

/***************************************/

SELECT M.FirstName AS PrimaryMemberFirstName,
	   M.LastName AS PrimaryMemberLastName,
	   M.MemberID as PrimaryMemberID,
	   R.Description AS RegionDescription, 
	   C.ClubName AS MembershipClub,
       C.ClubID as MMSClubID,
       M.JoinDate as PrimaryMember_JoinDate_Sort, 
       Replace(SubString(Convert(Varchar, M.JoinDate),1,3)+' '+LTRIM(SubString(Convert(Varchar, M.JoinDate),5,DataLength(Convert(Varchar, M.JoinDate))-12)),' '+Convert(Varchar,Year(M.JoinDate)),', '+Convert(Varchar,Year(M.JoinDate))) as PrimaryMemberJoinDate,
	   CO.CompanyName,
	   CO.AccountRepName, 
	   CO.CorporateCode,
	   CO.CompanyID,
	   P.Description AS MembershipTypeDescription, 
       VMS.Description AS MembershipStatusDescription,   
       IsNull(MS.CurrentPrice,0) * #PlanRate.PlanRate AS MembershipDues,
	   ISNull(#MJD.MembershipJrDues,0) * #PlanRate.PlanRate  as MembershipJrDues,
	   CASE WHEN CPTR.TaxPercentage IS NULL THEN 0  
	      ELSE (IsNull(MS.CurrentPrice,0) * #PlanRate.PlanRate) * (CPTR.TaxPercentage * .01) 
		  END TaxOnMembershipDues,
	   CASE WHEN #CPTR_JM.TaxPercentage IS NULL THEN 0
          ELSE (ISNull(#MJD.MembershipJrDues,0) * #PlanRate.PlanRate) *(#CPTR_JM.TaxPercentage * .01)
          END TaxOnJuniorDues,
	 @HeaderMembershipStatuses as HeaderMembershipStatuses,
	 @ReportRunDateTime AS ReportRunDateTime,
	 @ReportingCurrencyCode as ReportingCurrencyCode,
	 CO.AccountOwner,
	 CO.SubsidyMeasurement,
	 SubString(FamilyStatus.Description,1,6) as MembershipSize,
	 CASE When SubString(FamilyStatus.Description,1,6) = 'Single'
	      THEN 1
		  Else 0
		  END SingleMembershipFlag,
     CASE When SubString(FamilyStatus.Description,1,6) = 'Couple'
	      THEN 1
		  Else 0
		  END CoupleMembershipFlag,
     CASE When SubString(FamilyStatus.Description,1,6) = 'Family'
	      THEN 1
		  Else 0
		  END FamilyMembershipFlag,
	 MB.CurrentBalance as MembershipDuesBalance,
	 IsNull(MB.CurrentBalanceProducts,0) as MembershipRecurrentProductBalance,
	 MS.MembershipID,
	 Advisor.FirstName as OriginalAdvisorFirstName,
	 Advisor.LastName as OriginalAdvisorLastName
	 
  FROM vClub C
  JOIN #CompanyMembershipsRanked MS
    ON MS.ClubID=C.ClubID
  JOIN vMember M
    ON M.MemberID=MS.MemberID
  JOIN vValRegion R
    ON R.ValRegionID=C.ValRegionID
  JOIN vCompany CO
    ON MS.CompanyID=CO.CompanyID
  JOIN vMembershipType MT
    ON MS.MembershipTypeID=MT.MembershipTypeID
  JOIN vValMembershipTypeFamilyStatus as FamilyStatus
    ON MT.ValMembershipTypeFamilyStatusID = FamilyStatus.ValMembershipTypeFamilyStatusID
  JOIN vProduct P
    ON P.ProductID=MT.ProductID 
  JOIN vMembershipBalance MB
    ON MS.MembershipID = MB.MembershipID
  JOIN vValCurrencyCode VCC
    ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID
  JOIN #PlanRate
    ON VCC.CurrencyCode = #PlanRate.FromCurrencyCode
   AND YEAR(GETDATE()) = #PlanRate.PlanYear
  LEFT JOIN #ClubProductTaxRate CPTR
    ON CPTR.ProductID = P.ProductID
   AND CPTR.ClubID = MS.ClubID
  LEFT JOIN vValTaxType VTT
    ON CPTR.ValTaxTypeID = VTT.ValTaxTypeID
    -- junior member 
  LEFT JOIN #MembershipJuniorDues #MJD
       ON MS.MembershipID = #MJD.MembershipID
  LEFT JOIN #ClubProductTaxRate #CPTR_JM 
	   ON #CPTR_JM.ClubID = #MJD.ClubID 
	   AND #CPTR_JM.ProductID = #MJD.ProductID 
  JOIN vValMembershipStatus VMS
    ON MS.ValMembershipStatusID=VMS.ValMembershipStatusID
  LEFT JOIN vEmployee Advisor
    ON MS.AdvisorEmployeeID = Advisor.EmployeeID
  WHERE MS.MembershipMemberRank = 1



DROP TABLE #tmpList
DROP TABLE #CompanyIDList
DROP TABLE #MembershipTypeProductIDList
DROP TABLE #Clubs
DROP TABLE #CompanyMembers
DROP TABLE #PlanRate
DROP TABLE #CompanyMembershipsRanked
DROP TABLE #ClubProductTaxRate
DROP TABLE #CompanyMembershipClubs
DROP TABLE #MembershipJuniorDues
END





