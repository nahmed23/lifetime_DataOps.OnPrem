


CREATE PROC [dbo].[procCognos_ProjectedEFTTransactions_CorporateMemberships] (
       @AcctNumL4 VARCHAR(4),    
       @PaymentTypeList VARCHAR(1000),
       @CompanyID INT
)

AS
BEGIN 
SET XACT_ABORT ON
SET NOCOUNT ON

/***********************************************************
Sample execution stmt.
exec procCognos_ProjectedEFTTransactions_CorporateMemberships  '0','VISA',15305

************************************************************/

Declare @FirstOfNextMonth AS Datetime
Declare @ReportRunDateTime AS DATETIME
DECLARE @ReportDate AS Datetime

Set @FirstOfNextMonth = DateAdd(Month,1,(CONVERT(DATETIME,CONVERT(VARCHAR,(GETDATE() - DAY(GETDATE()-1)),110),110)))
SET @ReportRunDateTime = Replace(Substring(convert(varchar,getdate(),100),1,6)+', '+Substring(convert(varchar,GETDATE(),100),8,10)+' '+Substring(convert(varchar,getdate(),100),18,2),'  ',' ')
SET @ReportDate = GetDate()

DECLARE @NextAssessmentAfterProjectedAssessment DateTime
DECLARE @LastDayOfProjectedAssessmentMonth DateTime
SET @NextAssessmentAfterProjectedAssessment = DateAdd(month,1,@FirstOfNextMonth)
SET @LastDayOfProjectedAssessmentMonth = DateAdd(day,-1,@NextAssessmentAfterProjectedAssessment)

-- total tax percentage for a given product and club 
CREATE TABLE #ClubProductTaxRate (
	ClubID INT, 
	ProductID INT, 
	TaxPercentage SMALLMONEY 
	)

INSERT INTO #ClubProductTaxRate 
	SELECT CPTR.ClubID, CPTR.ProductID, Sum(TR.TaxPercentage) AS TaxPercentage 
	FROM dbo.vClubProductTaxRate CPTR
	JOIN dbo.vTaxRate TR ON  TR.TaxRateID = CPTR.TaxRateID
	GROUP BY CPTR.ClubID, CPTR.ProductID

CREATE TABLE #tmpList (StringField VARCHAR(50))
CREATE TABLE #PaymentType (Description VARCHAR(50))
       IF @PaymentTypeList <> 'All'
       BEGIN
           EXEC procParseStringList @PaymentTypeList
           INSERT INTO #PaymentType (Description) SELECT StringField FROM #tmpList
           TRUNCATE TABLE #tmpList
       END
       ELSE 
           INSERT INTO #PaymentType (Description) VALUES ('All')

/********  Foreign Currency Stuff ********/
DECLARE @ReportingCurrencyCode VARCHAR(15)
SET @ReportingCurrencyCode = 
(SELECT CASE WHEN COUNT(DISTINCT C.ValCurrencyCodeID) >=2 THEN 'USD' ELSE MAX(VCC.CurrencyCode) END AS ReportingCurrency
  FROM vClub C  
  JOIN vValCurrencyCode VCC ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID)

CREATE TABLE #PlanRate (PlanRate DECIMAL(14,4), FromCurrencyCode VARCHAR(15), PlanYear INT)
INSERT INTO #PlanRate
SELECT PlanExchangeRate, FromCurrencyCode, PlanYear
FROM PlanExchangeRate
WHERE ToCurrencyCode = @ReportingCurrencyCode


/***************************************/

--- Gather list of all memberships with selected corporate affiliation - Membership Company or Reimbursement Program Company
   
  ---- returns one record for all each member with an active a reimb. program for the selected company - UNION will remove duplicate membershipIDs
Select M.MembershipID,Company.CompanyName,Company.CorporateCode   
INTO #CompanyMembers
From vMember M
Join vMemberReimbursement MR
  On M.MemberID = MR.MemberID
Join vReimbursementProgram RP
  On MR.ReimbursementProgramID = RP.ReimbursementProgramID
Join vCompany Company
  On RP.CompanyID = Company.CompanyID
Join vMembership MS
  On M.MembershipID = MS.MembershipID
JOIN vValMembershipStatus VMS
  ON MS.ValMembershipStatusID = VMS.ValMembershipStatusID

Where MR.EnrollmentDate <= @ReportDate 
  AND ISNull(MR.TerminationDate,'1/1/2100') > @ReportDate   
  AND ISNull(MS.ExpirationDate,'1/1/2100')> @ReportDate 
  AND RP.CompanyID = @CompanyID
  AND M.ActiveFlag = 1
  AND VMS.Description IN ('Active', 'Late Activation', 'Non-Paid', 'Non-Paid, Late Activation', 'Pending Termination')


UNION  
  
    ------ returns membershipID for all memberships which have the selected membership company affiliation
  Select MS.MembershipID,Company.CompanyName,Company.CorporateCode
  From vMembership MS 
  JOIN vValMembershipStatus VMS
    ON MS.ValMembershipStatusID = VMS.ValMembershipStatusID
  JOIN vCompany Company
    ON MS.CompanyID = Company.CompanyID
 WHERE VMS.Description IN ('Active', 'Late Activation', 'Non-Paid', 'Non-Paid, Late Activation', 'Pending Termination')
   AND MS.CompanyID = @CompanyID



 ---- calculate Junior dues
Select MPT.MembershipID,
       PT.ProductID, 
	   C.ClubID,
       Sum(PTP.Price)  As MembershipJrDues
INTO #MembershipJuniorDues           
From vMembershipProductTier  MPT
 Join vProductTier PT
   On MPT.ProductTierID = PT.ProductTierID
 Join vMembership MS
   On MPT.MembershipID = MS.MembershipID
 Join #CompanyMembers #CompanyMembers
   On MS.MembershipID = #CompanyMembers.MembershipID
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
             Group by MPT.MembershipID,PT.ProductID, C.ClubID
             Order by MPT.MembershipID


SELECT #CompanyMembers.CompanyName,
	   VPT.Description PaymentTypeDescription, 
	   VR.Description RegionDescription, 
       C.ClubName, 
	   M.MemberID, 
	   M.FirstName, 
	   M.LastName, 
       CASE WHEN MS.ExpirationDate < @FirstOfNextMonth
	        THEN 0
	        WHEN CPTR.taxpercentage is null 
	        THEN MS.CurrentPrice * #PlanRate.PlanRate 
			ELSE (MS.CurrentPrice * #PlanRate.PlanRate) + ((MS.CurrentPrice * #PlanRate.PlanRate)*CPTR.taxpercentage/100) 
			END DuesPricePlusTax, 
	   VMS.Description MembershipStatusDescription, 
	   CASE WHEN (VMS.ValMembershipStatusID = 4 and MS.ActivationDate > @FirstOfNextMonth)  ---- Active Status
	        THEN 'EFT Only'
			WHEN (VMS.ValMembershipStatusID = 4 and MS.ActivationDate <= @FirstOfNextMonth)   
			THEN 'Assess and EFT'
			WHEN  VMS.ValMembershipStatusID in(6,7)     ---- Non-Paid & Non-Paid,Late Activation
			THEN 'Assess, No EFT'
			WHEN (VMS.ValMembershipStatusID = 5 and MS.ActivationDate < @FirstOfNextMonth) ---- Late Activation
			THEN 'Assess and EFT'
			WHEN (VMS.ValMembershipStatusID = 3 and MS.ActivationDate <= @FirstOfNextMonth) ---- Suspended
			THEN 'Assess and EFT'
			WHEN (VMS.ValMembershipStatusID = 2 and MS.ExpirationDate >= @FirstOfNextMonth)   ----- Pending Termination
	        THEN 'Assess and EFT'
			ELSE 'EFT Only'
			END ProjectedEFTProcessing,

	   @ReportRunDateTime as ReportRunDateTime, 
	   EFTO.ValEFTOptionID, 
       EFTO.Description EFTOptionDescription, 
	   #CompanyMembers.CorporateCode, 
       EFTA.MaskedAccountNumber,
	   CASE WHEN MS.ExpirationDate < @FirstOfNextMonth
	        THEN 0
	        WHEN CPTR_JM.taxpercentage is null 
	        THEN IsNull(#MJD.MembershipJrDues,0) * #PlanRate.PlanRate 
			ELSE  (IsNull(#MJD.MembershipJrDues,0) * #PlanRate.PlanRate) + ((IsNull(#MJD.MembershipJrDues,0) * #PlanRate.PlanRate) * CPTR_JM.taxpercentage/100) 
			END JuniorDuesPricePlusTax,
	   ((CASE WHEN MS.ExpirationDate < @FirstOfNextMonth
	        THEN 0
	        WHEN CPTR.taxpercentage is null 
	        THEN MS.CurrentPrice * #PlanRate.PlanRate 
			ELSE (MS.CurrentPrice * #PlanRate.PlanRate) + ((MS.CurrentPrice * #PlanRate.PlanRate)*CPTR.taxpercentage/100) 
			END) + (CASE WHEN MS.ExpirationDate < @FirstOfNextMonth
	                     THEN 0
			             WHEN CPTR_JM.taxpercentage is null 
	                     THEN IsNull(#MJD.MembershipJrDues,0) * #PlanRate.PlanRate 
			             ELSE  (IsNull(#MJD.MembershipJrDues,0) * #PlanRate.PlanRate) + ((IsNull(#MJD.MembershipJrDues,0) * #PlanRate.PlanRate) * CPTR_JM.taxpercentage/100) 
			         END)) MonthlyAndJuniorDuesPlusTax, 
       @ReportingCurrencyCode as ReportingCurrencyCode,
	   (MSB.EFTAmount + IsNull(EFTAmountProducts,0))* #PlanRate.PlanRate as EFTAmountBalance,
	   MS.ExpirationDate	  
  
 INTO #Results
  FROM dbo.vMembership MS
  JOIN #CompanyMembers #CompanyMembers
       ON MS.MembershipID = #CompanyMembers.MembershipID
  JOIN dbo.vMember M
       ON M.MembershipID = MS.MembershipID
  JOIN dbo.vMembershipBalance MSB
       ON MSB.MembershipID = MS.MembershipID
  JOIN dbo.vClub C
       ON C.ClubID = MS.ClubID
  JOIN dbo.vValRegion VR
       ON VR.ValRegionID = C.ValRegionID
  JOIN dbo.vClubProduct CP
       ON C.ClubID = CP.ClubID
  JOIN dbo.vMembershipType MT
       ON MS.MembershipTypeID = MT.MembershipTypeID
       AND MT.ProductID = CP.ProductID
/********** Foreign Currency Stuff **********/
  JOIN vValCurrencyCode VCC
       ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID
  JOIN #PlanRate
       ON VCC.CurrencyCode = #PlanRate.FromCurrencyCode
      AND YEAR(GETDATE()) = #PlanRate.PlanYear

/*******************************************/
  -- membership type 
  LEFT JOIN #ClubProductTaxRate CPTR 
	   ON CPTR.ClubID = CP.ClubID 
	   AND CPTR.ProductID = CP.ProductID   
  JOIN dbo.vValMembershipStatus VMS
       ON VMS.ValMembershipStatusID = MS.ValMembershipStatusID
  JOIN dbo.vValEFTOption EFTO
       ON MS.ValEFTOptionID = EFTO.ValEFTOptionID
  JOIN dbo.vEFTAccountDetail EFTA 
       ON MS.MembershipID = EFTA.MembershipID
  JOIN dbo.vValPaymentType VPT
       ON EFTA.ValPaymentTypeID = VPT.ValPaymentTypeID
  JOIN #PaymentType
       ON VPT.Description = #PaymentType.Description
  -- junior member 
  LEFT JOIN #MembershipJuniorDues #MJD
       ON MS.MembershipID = #MJD.MembershipID
  LEFT JOIN #ClubProductTaxRate CPTR_JM 
	   ON CPTR_JM.ClubID = #MJD.ClubID 
	   AND CPTR_JM.ProductID = #MJD.ProductID                 
 WHERE M.ValMemberTypeID = 1 
       AND VMS.Description IN ('Active', 'Late Activation', 'Non-Paid', 
           'Non-Paid, Late Activation', 'Pending Termination', 'Suspended')  
	   AND (RIGHT(EFTA.MaskedAccountNumber, LEN(@AcctNumL4)) = @AcctNumL4 or @AcctNumL4 = '0')


 Select  CompanyName +': '+ PaymentTypeDescription + ' # ' + MaskedAccountNumber as CompanyGroupHeader,
         RegionDescription  + '  -  ' +ClubName as ClubGroupHeader,	
         CompanyName,
         PaymentTypeDescription,
		 RegionDescription,
		 ClubName,
         MemberID, 
		 LastName + ', '+ FirstName as MemberName,
		 CASE WHEN #Results.DuesPricePlusTax = 0
		    THEN 0
		    WHEN IsNull(ExpirationDimDate.CalendarDate,'1/1/1900') = '1/1/1900'
	        THEN #Results.DuesPricePlusTax
			WHEN ExpirationDimDate.CalendarDate >= @LastDayOfProjectedAssessmentMonth
			THEN #Results.DuesPricePlusTax
			ELSE  (ExpirationDimDate.DayNumberInCalendarMonth / ExpirationDimDate.NumberOfDaysInMonth)* #Results.DuesPricePlusTax
			END DuesPricePlusTax, 
          CASE WHEN #Results.JuniorDuesPricePlusTax = 0
		    THEN 0
		    WHEN IsNull(ExpirationDimDate.CalendarDate,'1/1/1900') = '1/1/1900'
	        THEN #Results.JuniorDuesPricePlusTax
			WHEN ExpirationDimDate.CalendarDate >= @LastDayOfProjectedAssessmentMonth
			THEN #Results.JuniorDuesPricePlusTax
			ELSE  (ExpirationDimDate.DayNumberInCalendarMonth / ExpirationDimDate.NumberOfDaysInMonth)* #Results.JuniorDuesPricePlusTax
			END JuniorDuesPricePlusTax,
		 CASE WHEN ValEFTOptionID = 1   -----  Active  EFT
		      THEN Convert(Varchar,Convert(Decimal(10,2),EFTAmountBalance))
			  ELSE EFTOptionDescription
			  END EFTAccountBalance,
		 MembershipStatusDescription,
		 ProjectedEFTProcessing,
		 CASE WHEN ValEFTOptionID <> 1   -----  Active  EFT
		     THEN 0
			  WHEN ProjectedEFTProcessing  = 'EFT Only'
			  THEN EFTAmountBalance
			  WHEN ProjectedEFTProcessing  = 'Assess and EFT'
			  THEN (EFTAmountBalance + (CASE WHEN IsNull(ExpirationDimDate.CalendarDate,'1/1/1900') = '1/1/1900'
	                                        THEN #Results.MonthlyAndJuniorDuesPlusTax
			                                WHEN ExpirationDimDate.CalendarDate >= @LastDayOfProjectedAssessmentMonth
			                                THEN #Results.MonthlyAndJuniorDuesPlusTax
			                                ELSE  (ExpirationDimDate.DayNumberInCalendarMonth / ExpirationDimDate.NumberOfDaysInMonth)* #Results.MonthlyAndJuniorDuesPlusTax
			                                END))
			  ELSE 0
			  END ProjectedEFT,
		  MaskedAccountNumber,
		  ReportRunDateTime,
		  ReportingCurrencyCode ----,
		  ------#Results.ExpirationDate
    From #Results
	Left Join vReportDimDate ExpirationDimDate
	   ON #Results.ExpirationDate = ExpirationDimDate.CalendarDate
 
 DROP TABLE #ClubProductTaxRate
 DROP TABLE #PlanRate
 DROP TABLE #MembershipJuniorDues
 DROP TABLE #tmpList
 DROP TABLE #PaymentType
 DROP TABLE #Results
 DROP TABLE #CompanyMembers

END



