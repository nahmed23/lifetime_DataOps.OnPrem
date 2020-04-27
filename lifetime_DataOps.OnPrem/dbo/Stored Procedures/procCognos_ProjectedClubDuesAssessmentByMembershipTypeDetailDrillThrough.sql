

CREATE PROC [dbo].[procCognos_ProjectedClubDuesAssessmentByMembershipTypeDetailDrillThrough] (
  @ClubIDs varchar(1000),
  @ProjectionAssessmentDate Datetime,
  @CurrencyCode VARCHAR(3)
  )
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

/* =============================================
-- Object:            dbo.procCognos_ProjectedClubDuesAssessmentByMembershipTypeDetailDrillThrough
-- Description:        Returns the projected assessed dues plus sales tax
--                    For a selected month's assessment

Exec procCognos_ProjectedClubDuesAssessmentByMembershipTypeDetailDrillThrough 151,'Nov 1, 2015 12:00:00 AM', 'USD'

-- ============================================= */

---- Parse the ClubIDs into a temp table
CREATE Table #tmpList (StringField VARCHAR(50))
Exec ProcParseIntegerList @ClubIDs
Create Table #Clubs (ClubID INT)
Insert Into #Clubs(ClubID) Select StringField from #tmpList

/********  Foreign Currency Stuff ********/
DECLARE @ReportingCurrencyCode VARCHAR(15)
SET @ReportingCurrencyCode = @CurrencyCode

CREATE TABLE #PlanRate (PlanRate DECIMAL(14,4), FromCurrencyCode VARCHAR(15), PlanYear INT)
INSERT INTO #PlanRate
SELECT PlanExchangeRate, FromCurrencyCode, PlanYear
FROM PlanExchangeRate
WHERE PlanYear = Year(@ProjectionAssessmentDate)  
  AND ToCurrencyCode = @ReportingCurrencyCode

CREATE TABLE #ToUSDPlanRate (PlanRate DECIMAL(14,4), FromCurrencyCode VARCHAR(15), PlanYear INT)
INSERT INTO #ToUSDPlanRate
SELECT PlanExchangeRate, FromCurrencyCode, PlanYear
FROM PlanExchangeRate
WHERE PlanYear = Year(@ProjectionAssessmentDate)  
  AND ToCurrencyCode = 'USD'

-- total tax percentage for a given product and club 
CREATE TABLE #ClubProductTaxRate (
    ClubID INT, 
    ProductID INT, 
    TaxPercentage SMALLMONEY)

INSERT INTO #ClubProductTaxRate 
    SELECT CPTR.ClubID, CPTR.ProductID, Sum(TR.TaxPercentage) AS TaxPercentage 
    FROM vClubProductTaxRate CPTR
    JOIN dbo.vTaxRate TR ON  TR.TaxRateID = CPTR.TaxRateID
    GROUP BY CPTR.ClubID, CPTR.ProductID

DECLARE @ReportRunDateTime VARCHAR(21) 
SET @ReportRunDateTime = Replace(Substring(convert(varchar,getdate(),100),1,6)+', '+Substring(convert(varchar,GETDATE(),100),8,10)+' '+Substring(convert(varchar,getdate(),100),18,2),'  ',' ')

DECLARE @NextAssessmentAfterProjectedAssessment DateTime
DECLARE @LastDayOfProjectedAssessmentMonth DateTime
SET @NextAssessmentAfterProjectedAssessment = DateAdd(month,1,@ProjectionAssessmentDate)
SET @LastDayOfProjectedAssessmentMonth = DateAdd(day,-1,@NextAssessmentAfterProjectedAssessment)

----- Find all the memberships which have requested a conversion to Flex membership
----- which would take effect between the run date and the projected assessment date. Then calculate
----- what the adjusted dues assessment would be plus sales tax.

CREATE TABLE #FlexConversions (
    MembershipID INT,
    MembershipType VARCHAR(100),
    DuesPrice DECIMAL(10,2),
    DuesItemAmount DECIMAL(10,2),
    DuesSalesTax DECIMAL(10,2))

INSERT INTO #FlexConversions
SELECT MembershipsConvertingToFlex.MembershipID, 
       MembershipsConvertingToFlex.MembershipType,
       CASE WHEN CPTR.taxpercentage is null THEN MembershipsConvertingToFlex.AgreementPrice 
         ELSE MembershipsConvertingToFlex.AgreementPrice  + (MembershipsConvertingToFlex.AgreementPrice * CPTR.taxpercentage/100) 
         END DuesPrice,
       MembershipsConvertingToFlex.AgreementPrice AS DuesItemAmount, 
       CASE WHEN CPTR.taxpercentage is null THEN 0 
         ELSE   MembershipsConvertingToFlex.AgreementPrice * CPTR.taxpercentage/100  
         END DuesSalesTax
  FROM vMembership MS
  JOIN #Clubs tmpC
    ON tmpC.ClubID = MS.ClubID
  JOIN (SELECT DISTINCT MMR.MembershipID,P.Description as MembershipType,P.ProductID,MMR.AgreementPrice
      FROM vMembershipModificationRequest MMR
      Join vProduct P
      ON MMR.MembershipTypeID = P.ProductID
      WHERE MMR.ValMembershipModificationRequestTypeID = 3
      AND MMR.ValMembershipModificationRequestStatusID <> 3
      AND MMR.EffectiveDate > GETDATE()
      AND MMR.EffectiveDate <= @ProjectionAssessmentDate
      ) MembershipsConvertingToFlex 
    ON MembershipsConvertingToFlex.MembershipID = MS.MembershipID
  JOIN vClubProduct CP
    ON CP.ProductID = MembershipsConvertingToFlex.ProductID
    AND CP.ClubID = MS.CLubID
  LEFT JOIN #ClubProductTaxRate CPTR 
    ON CPTR.ClubID = MS.ClubID 
    AND CPTR.ProductID = CP.ProductID   

---
---  Return all memberships to be assessed on the Projection assessment date, barring any
---  status changes before that time, taking into account and modifying the data for any 
---  conversion to a Flex Membership set to automatically occur before the assessment. Also, 
---  prorating final month assessment if membership is set to term. mid-month
--- 

SELECT C.ClubName, MS.MembershipID,M.MemberID, M.FirstName, M.LastName,
       COALESCE(FC.MembershipType, P.Description) MembershipType, 
       VCC.CurrencyCode as LocalCurrencyCode,
       #PlanRate.PlanRate,
       @ReportingCurrencyCode as ReportingCurrencyCode,      
       CASE WHEN FC.DuesPrice IS NOT NULL THEN FC.DuesPrice * #PlanRate.PlanRate
            WHEN CPTR.taxpercentage is null THEN MS.CurrentPrice * #PlanRate.PlanRate
            ELSE (MS.CurrentPrice + (MS.CurrentPrice*CPTR.taxpercentage/100))*#PlanRate.PlanRate 
            END as DuesPrice,
       CASE WHEN FC.DuesPrice IS NOT NULL THEN FC.DuesPrice
            WHEN CPTR.taxpercentage is null THEN MS.CurrentPrice 
            ELSE MS.CurrentPrice + (MS.CurrentPrice*CPTR.taxpercentage/100) 
            END as LocalCurrency_DuesPrice, 
       CASE WHEN FC.DuesPrice IS NOT NULL THEN FC.DuesPrice * #ToUSDPlanRate.PlanRate
            WHEN CPTR.taxpercentage is null THEN MS.CurrentPrice * #ToUSDPlanRate.PlanRate
            ELSE (MS.CurrentPrice + (MS.CurrentPrice*CPTR.taxpercentage/100))* #ToUSDPlanRate.PlanRate
            END as USD_DuesPrice,
       -- item amount       
       CASE WHEN FC.DuesItemAmount IS NOT NULL OR FC.DuesItemAmount<>0 THEN FC.DuesItemAmount * #PlanRate.PlanRate
                ELSE MS.CurrentPrice * #PlanRate.PlanRate
                END as DuesItemAmount, 
       CASE WHEN FC.DuesItemAmount IS NOT NULL OR FC.DuesItemAmount<>0 THEN FC.DuesItemAmount
                ELSE MS.CurrentPrice 
                END as LocalCurrency_DuesItemAmount, 
       CASE WHEN FC.DuesItemAmount IS NOT NULL OR FC.DuesItemAmount<>0 THEN FC.DuesItemAmount * #ToUSDPlanRate.PlanRate
                ELSE MS.CurrentPrice * #ToUSDPlanRate.PlanRate
                END as USD_DuesItemAmount, 
       -- salex tax       
       CASE WHEN FC.DuesSalesTax IS NOT NULL OR FC.DuesSalesTax<> 0 THEN FC.DuesSalesTax * #PlanRate.PlanRate
                WHEN CPTR.taxpercentage is null THEN 0 
                ELSE (MS.CurrentPrice * #PlanRate.PlanRate)*CPTR.taxpercentage/100 
                END as DuesSalesTax,
       CASE WHEN FC.DuesSalesTax IS NOT NULL OR FC.DuesSalesTax<> 0 THEN FC.DuesSalesTax
                WHEN CPTR.taxpercentage is null THEN 0 
                ELSE MS.CurrentPrice*CPTR.taxpercentage/100 
                END as LocalCurrency_DuesSalesTax, 
       CASE WHEN FC.DuesSalesTax IS NOT NULL OR FC.DuesSalesTax<> 0 THEN FC.DuesSalesTax * #ToUSDPlanRate.PlanRate
                WHEN CPTR.taxpercentage is null THEN 0 
                ELSE (MS.CurrentPrice * #ToUSDPlanRate.PlanRate)*CPTR.taxpercentage/100 
                END as USD_DuesSalesTax,
       CASE WHEN FC.DuesPrice IS NOT NULL THEN 0
            ELSE JuniorDues.AssessableJrMembers
            END as JuniorDuesCount,
       CASE WHEN FC.DuesPrice IS NOT NULL THEN 0
            WHEN CPTR_JM.taxpercentage is null THEN (JuniorDues.MembershipJrDues * #PlanRate.PlanRate)
            ELSE (JuniorDues.MembershipJrDues * #PlanRate.PlanRate) + ((JuniorDues.MembershipJrDues * #PlanRate.PlanRate) * CPTR_JM.taxpercentage/100)
            END as JuniorDuesPrice,
       CASE WHEN FC.DuesPrice IS NOT NULL THEN 0
            WHEN CPTR_JM.taxpercentage is null THEN JuniorDues.MembershipJrDues  
            ELSE JuniorDues.MembershipJrDues  + (JuniorDues.MembershipJrDues  * CPTR_JM.taxpercentage/100)
            END as LocalCurrency_JuniorDuesPrice,
       CASE WHEN FC.DuesPrice IS NOT NULL THEN 0
            WHEN CPTR_JM.taxpercentage is null THEN (JuniorDues.MembershipJrDues * #ToUSDPlanRate.PlanRate)
            ELSE (JuniorDues.MembershipJrDues * #ToUSDPlanRate.PlanRate) + ((JuniorDues.MembershipJrDues * #ToUSDPlanRate.PlanRate) * CPTR_JM.taxpercentage/100)
            END as USD_JuniorDuesPrice,
       -- junior itemamount       
       CASE WHEN FC.DuesPrice IS NOT NULL OR FC.DuesPrice<>0 THEN 0
                ELSE (JuniorDues.MembershipJrDues  * #PlanRate.PlanRate) 
                END as JuniorDuesItemAmount,
       CASE WHEN FC.DuesPrice IS NOT NULL OR FC.DuesPrice<>0 THEN 0
                ELSE JuniorDues.MembershipJrDues 
                END as LocalCurrency_JuniorDuesItemAmount,
       CASE WHEN FC.DuesPrice IS NOT NULL OR FC.DuesPrice<>0 THEN 0
                ELSE (JuniorDues.MembershipJrDues * #ToUSDPlanRate.PlanRate) 
                END as USD_JuniorDuesItemAmount,
       -- junior sale tax       
       CASE WHEN FC.DuesPrice IS NOT NULL OR FC.DuesPrice<>0 THEN 0
                WHEN CPTR_JM.taxpercentage is null THEN 0
                ELSE (JuniorDues.MembershipJrDues * #PlanRate.PlanRate) * CPTR_JM.taxpercentage/100
                END as JuniorDuesSalesTax,
       CASE WHEN FC.DuesPrice IS NOT NULL OR FC.DuesPrice<>0 THEN 0
                WHEN CPTR_JM.taxpercentage is null THEN 0
                ELSE JuniorDues.MembershipJrDues * CPTR_JM.taxpercentage/100
                END as LocalCurrency_JuniorDuesSalesTax,
       CASE WHEN FC.DuesPrice IS NOT NULL OR FC.DuesPrice<>0 THEN 0
                WHEN CPTR_JM.taxpercentage is null THEN 0
                ELSE (JuniorDues.MembershipJrDues * #ToUSDPlanRate.PlanRate) * CPTR_JM.taxpercentage/100
                END as USD_JuniorDuesSalesTax,
       VR.Description RegionDescription,
       VMS.Description MembershipStatusDescription, 
       VMS.ValMembershipStatusID,MS.CreatedDateTime,
       MS.ActivationDate, 
	   MS.ExpirationDate, 
       @ProjectionAssessmentDate as ProjectedAssessmentDate,
       Replace(Substring(convert(varchar,@ProjectionAssessmentDate,100),1,6)+', '+Substring(convert(varchar,@ProjectionAssessmentDate,100),8,4),'  ',' ') AS ProjectionAssessmentDateHeader,
       CASE WHEN FC.DuesPrice IS NOT NULL THEN 1 ELSE 0 END ConvertingFlexMembership,
       @ReportRunDateTime AS ReportRunDateTime
  INTO #Results
  FROM vMembership MS
  JOIN dbo.vMember M
       ON M.MembershipID = MS.MembershipID
  JOIN vClub C
       ON C.ClubID = MS.ClubID
   JOIN #Clubs tmpC
       ON tmpC.ClubID = MS.ClubID
  JOIN dbo.vValRegion VR
       ON VR.ValRegionID = C.ValRegionID
  JOIN vClubProduct CP
       ON MS.ClubID = CP.ClubID
  JOIN dbo.vMembershipType MT
       ON MS.MembershipTypeID = MT.MembershipTypeID
       AND MT.ProductID = CP.ProductID
  JOIN dbo.vProduct P
       ON P.ProductID = MT.ProductID
/********** Foreign Currency Stuff **********/
  JOIN vValCurrencyCode VCC
       ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID
  JOIN #PlanRate
       ON VCC.CurrencyCode = #PlanRate.FromCurrencyCode
      AND YEAR(@ProjectionAssessmentDate) = #PlanRate.PlanYear
  JOIN #ToUSDPlanRate
       ON VCC.CurrencyCode = #ToUSDPlanRate.FromCurrencyCode
      AND YEAR(@ProjectionAssessmentDate) = #ToUSDPlanRate.PlanYear
/*******************************************/ 
  -- membership type 
 LEFT JOIN #ClubProductTaxRate CPTR 
      ON CPTR.ClubID = CP.ClubID 
      AND CPTR.ProductID = CP.ProductID 
  JOIN dbo.vValMembershipStatus VMS
       ON VMS.ValMembershipStatusID = MS.ValMembershipStatusID
  -- junior member 
    LEFT JOIN (Select Count(M.MemberID)as AssessableJrMembers, MPT.MembershipID,PT.ProductID,
             C.ClubID, Sum(PTP.Price)As MembershipJrDues
               From vMembershipProductTier  MPT
               Join vProductTier PT
                On MPT.ProductTierID = PT.ProductTierID
               Join vMembership MS
                On MPT.MembershipID = MS.MembershipID
               Join vClub C
                On MS.ClubID = C.ClubID
               Join #Clubs #C
                On C.ClubID = #C.ClubID
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
               AND PT.ValProductTierTypeID = 1
               And (M.AssessJrMemberDuesFlag = 1 or M.AssessJrMemberDuesFlag is null )
               AND (C.AssessJrMemberDuesFlag = 1 or C.AssessJrMemberDuesFlag is null )
               AND (MT.AssessJrMemberDuesFlag = 1 or MT.AssessJrMemberDuesFlag is null )
             Group by MPT.MembershipID,PT.ProductID,C.ClubID
            ) JuniorDues
       ON MS.MembershipID = JuniorDues.MembershipID
    LEFT JOIN #ClubProductTaxRate CPTR_JM 
       ON CPTR_JM.ClubID = JuniorDues.ClubID 
       AND CPTR_JM.ProductID = JuniorDues.ProductID   
    LEFT JOIN #FlexConversions FC
    ON FC.MembershipID = MS.MembershipID            
 WHERE M.ValMemberTypeID = 1 
       AND ((VMS.Description in('Active', 'Non-Paid') 
              AND (MS.ExpirationDate >= @ProjectionAssessmentDate OR MS.ExpirationDate Is Null))
            OR
            (VMS.Description in ('Late Activation','Suspended','Non-Paid, Late Activation')
              AND MS.ActivationDate <= @ProjectionAssessmentDate )
            OR
             (VMS.Description in('Pending Termination') 
              AND MS.ExpirationDate >= @ProjectionAssessmentDate ))
       
  ---- Adjust projected amounts when membership is set to terminate before the end of the projected assessment month
Select #Results.ClubName, 
       #Results.MembershipID,
	   #Results.MemberID, 
	   #Results.FirstName, 
	   #Results.LastName,
       #Results.MembershipType, 
       #Results.LocalCurrencyCode,
       #Results.PlanRate,
       #Results.ReportingCurrencyCode,
	   CASE WHEN IsNull(ExpirationDimDate.CalendarDate,'1/1/1900') = '1/1/1900'
	        THEN #Results.DuesPrice
			WHEN ExpirationDimDate.CalendarDate >= @LastDayOfProjectedAssessmentMonth
			THEN #Results.DuesPrice
			ELSE  (ExpirationDimDate.DayNumberInCalendarMonth / ExpirationDimDate.NumberOfDaysInMonth)* #Results.DuesPrice
			END DuesPrice,
	   CASE WHEN IsNull(ExpirationDimDate.CalendarDate,'1/1/1900') = '1/1/1900'
	        THEN #Results.LocalCurrency_DuesPrice
			WHEN ExpirationDimDate.CalendarDate >= @LastDayOfProjectedAssessmentMonth
			THEN #Results.LocalCurrency_DuesPrice
			ELSE  (ExpirationDimDate.DayNumberInCalendarMonth / ExpirationDimDate.NumberOfDaysInMonth)* #Results.LocalCurrency_DuesPrice
			END LocalCurrency_DuesPrice,
	   CASE WHEN IsNull(ExpirationDimDate.CalendarDate,'1/1/1900') = '1/1/1900'
	        THEN #Results.USD_DuesPrice
			WHEN ExpirationDimDate.CalendarDate >= @LastDayOfProjectedAssessmentMonth
			THEN #Results.USD_DuesPrice
			ELSE  (ExpirationDimDate.DayNumberInCalendarMonth / ExpirationDimDate.NumberOfDaysInMonth)* #Results.USD_DuesPrice
			END USD_DuesPrice,

       -- item amount  
	   CASE WHEN IsNull(ExpirationDimDate.CalendarDate,'1/1/1900') = '1/1/1900'
	        THEN #Results.DuesItemAmount
			WHEN ExpirationDimDate.CalendarDate >= @LastDayOfProjectedAssessmentMonth
			THEN #Results.DuesItemAmount
			ELSE  (ExpirationDimDate.DayNumberInCalendarMonth / ExpirationDimDate.NumberOfDaysInMonth)* #Results.DuesItemAmount
			END DuesItemAmount,     
 	   CASE WHEN IsNull(ExpirationDimDate.CalendarDate,'1/1/1900') = '1/1/1900'
	        THEN #Results.LocalCurrency_DuesItemAmount
			WHEN ExpirationDimDate.CalendarDate >= @LastDayOfProjectedAssessmentMonth
			THEN #Results.LocalCurrency_DuesItemAmount
			ELSE  (ExpirationDimDate.DayNumberInCalendarMonth / ExpirationDimDate.NumberOfDaysInMonth)* #Results.LocalCurrency_DuesItemAmount
			END LocalCurrency_DuesItemAmount,
 	   CASE WHEN IsNull(ExpirationDimDate.CalendarDate,'1/1/1900') = '1/1/1900'
	        THEN #Results.USD_DuesItemAmount
			WHEN ExpirationDimDate.CalendarDate >= @LastDayOfProjectedAssessmentMonth
			THEN #Results.USD_DuesItemAmount
			ELSE  (ExpirationDimDate.DayNumberInCalendarMonth / ExpirationDimDate.NumberOfDaysInMonth)* #Results.USD_DuesItemAmount
			END USD_DuesItemAmount,
 
       -- salex tax    
	   CASE WHEN IsNull(ExpirationDimDate.CalendarDate,'1/1/1900') = '1/1/1900'
	        THEN #Results.DuesSalesTax
			WHEN ExpirationDimDate.CalendarDate >= @LastDayOfProjectedAssessmentMonth
			THEN #Results.DuesSalesTax
			ELSE  (ExpirationDimDate.DayNumberInCalendarMonth / ExpirationDimDate.NumberOfDaysInMonth)* #Results.DuesSalesTax
			END DuesSalesTax,   
	   CASE WHEN IsNull(ExpirationDimDate.CalendarDate,'1/1/1900') = '1/1/1900'
	        THEN #Results.LocalCurrency_DuesSalesTax
			WHEN ExpirationDimDate.CalendarDate >= @LastDayOfProjectedAssessmentMonth
			THEN #Results.LocalCurrency_DuesSalesTax
			ELSE  (ExpirationDimDate.DayNumberInCalendarMonth / ExpirationDimDate.NumberOfDaysInMonth)* #Results.LocalCurrency_DuesSalesTax
			END LocalCurrency_DuesSalesTax, 
	   CASE WHEN IsNull(ExpirationDimDate.CalendarDate,'1/1/1900') = '1/1/1900'
	        THEN #Results.USD_DuesSalesTax
			WHEN ExpirationDimDate.CalendarDate >= @LastDayOfProjectedAssessmentMonth
			THEN #Results.USD_DuesSalesTax
			ELSE  (ExpirationDimDate.DayNumberInCalendarMonth / ExpirationDimDate.NumberOfDaysInMonth)* #Results.USD_DuesSalesTax
			END USD_DuesSalesTax, 
       #Results.JuniorDuesCount,
	   CASE WHEN IsNull(ExpirationDimDate.CalendarDate,'1/1/1900') = '1/1/1900'
	        THEN #Results.JuniorDuesPrice
			WHEN ExpirationDimDate.CalendarDate >= @LastDayOfProjectedAssessmentMonth
			THEN #Results.JuniorDuesPrice
			ELSE  (ExpirationDimDate.DayNumberInCalendarMonth / ExpirationDimDate.NumberOfDaysInMonth)* #Results.JuniorDuesPrice
			END JuniorDuesPrice,
	   CASE WHEN IsNull(ExpirationDimDate.CalendarDate,'1/1/1900') = '1/1/1900'
	        THEN #Results.LocalCurrency_JuniorDuesPrice
			WHEN ExpirationDimDate.CalendarDate >= @LastDayOfProjectedAssessmentMonth
			THEN #Results.LocalCurrency_JuniorDuesPrice
			ELSE  (ExpirationDimDate.DayNumberInCalendarMonth / ExpirationDimDate.NumberOfDaysInMonth)* #Results.LocalCurrency_JuniorDuesPrice
			END LocalCurrency_JuniorDuesPrice,
	   CASE WHEN IsNull(ExpirationDimDate.CalendarDate,'1/1/1900') = '1/1/1900'
	        THEN #Results.USD_JuniorDuesPrice
			WHEN ExpirationDimDate.CalendarDate >= @LastDayOfProjectedAssessmentMonth
			THEN #Results.USD_JuniorDuesPrice
			ELSE  (ExpirationDimDate.DayNumberInCalendarMonth / ExpirationDimDate.NumberOfDaysInMonth)* #Results.USD_JuniorDuesPrice
			END USD_JuniorDuesPrice,

       -- junior itemamount  
	   CASE WHEN IsNull(ExpirationDimDate.CalendarDate,'1/1/1900') = '1/1/1900'
	        THEN #Results.JuniorDuesItemAmount
			WHEN ExpirationDimDate.CalendarDate >= @LastDayOfProjectedAssessmentMonth
			THEN #Results.JuniorDuesItemAmount
			ELSE  (ExpirationDimDate.DayNumberInCalendarMonth / ExpirationDimDate.NumberOfDaysInMonth)* #Results.JuniorDuesItemAmount
			END JuniorDuesItemAmount,     
	   CASE WHEN IsNull(ExpirationDimDate.CalendarDate,'1/1/1900') = '1/1/1900'
	        THEN #Results.LocalCurrency_JuniorDuesItemAmount
			WHEN ExpirationDimDate.CalendarDate >= @LastDayOfProjectedAssessmentMonth
			THEN #Results.LocalCurrency_JuniorDuesItemAmount
			ELSE  (ExpirationDimDate.DayNumberInCalendarMonth / ExpirationDimDate.NumberOfDaysInMonth)* #Results.LocalCurrency_JuniorDuesItemAmount
			END LocalCurrency_JuniorDuesItemAmount, 
	   CASE WHEN IsNull(ExpirationDimDate.CalendarDate,'1/1/1900') = '1/1/1900'
	        THEN #Results.USD_JuniorDuesItemAmount
			WHEN ExpirationDimDate.CalendarDate >= @LastDayOfProjectedAssessmentMonth
			THEN #Results.USD_JuniorDuesItemAmount
			ELSE  (ExpirationDimDate.DayNumberInCalendarMonth / ExpirationDimDate.NumberOfDaysInMonth)* #Results.USD_JuniorDuesItemAmount
			END USD_JuniorDuesItemAmount, 

       -- junior sale tax  
	   CASE WHEN IsNull(ExpirationDimDate.CalendarDate,'1/1/1900') = '1/1/1900'
	        THEN #Results.JuniorDuesSalesTax
			WHEN ExpirationDimDate.CalendarDate >= @LastDayOfProjectedAssessmentMonth
			THEN #Results.JuniorDuesSalesTax
			ELSE  (ExpirationDimDate.DayNumberInCalendarMonth / ExpirationDimDate.NumberOfDaysInMonth)* #Results.JuniorDuesSalesTax
			END JuniorDuesSalesTax,  
	   CASE WHEN IsNull(ExpirationDimDate.CalendarDate,'1/1/1900') = '1/1/1900'
	        THEN #Results.LocalCurrency_JuniorDuesSalesTax
			WHEN ExpirationDimDate.CalendarDate >= @LastDayOfProjectedAssessmentMonth
			THEN #Results.LocalCurrency_JuniorDuesSalesTax
			ELSE  (ExpirationDimDate.DayNumberInCalendarMonth / ExpirationDimDate.NumberOfDaysInMonth)* #Results.LocalCurrency_JuniorDuesSalesTax
			END LocalCurrency_JuniorDuesSalesTax,  		    
	   CASE WHEN IsNull(ExpirationDimDate.CalendarDate,'1/1/1900') = '1/1/1900'
	        THEN #Results.USD_JuniorDuesSalesTax
			WHEN ExpirationDimDate.CalendarDate >= @LastDayOfProjectedAssessmentMonth
			THEN #Results.USD_JuniorDuesSalesTax
			ELSE  (ExpirationDimDate.DayNumberInCalendarMonth / ExpirationDimDate.NumberOfDaysInMonth)* #Results.USD_JuniorDuesSalesTax
			END USD_JuniorDuesSalesTax, 

       RegionDescription,
       MembershipStatusDescription, 
       ValMembershipStatusID,
	   CreatedDateTime,
       ActivationDate, 
	   ExpirationDate, 
       ProjectedAssessmentDate,
       ProjectionAssessmentDateHeader,
       ConvertingFlexMembership,
       ReportRunDateTime
	FROM #Results #Results
	 Left Join vReportDimDate ExpirationDimDate
	   ON #Results.ExpirationDate = ExpirationDimDate.CalendarDate

 DROP TABLE #Clubs
 DROP TABLE #tmpList
 DROP TABLE #FlexConversions
 DROP TABLE #PlanRate
 DROP TABLE #ToUSDPlanRate
 DROP TABLE #Results


END


