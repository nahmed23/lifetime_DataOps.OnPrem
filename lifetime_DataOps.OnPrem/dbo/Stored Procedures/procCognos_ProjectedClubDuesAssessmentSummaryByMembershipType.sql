




CREATE    PROC [dbo].[procCognos_ProjectedClubDuesAssessmentSummaryByMembershipType] (
  @ClubIDs varchar(1000),
  @ProjectionAssessmentDate datetime)
AS
SET XACT_ABORT ON
SET NOCOUNT ON

/* =============================================
 Object:            dbo.procCognos_ProjectedClubDuesAssessmentSummarybyMembershipType
 Description:        Returns the projected assessed dues plus sales tax
                    For a selected month's assessment
 Test Script:        
 Exec procCognos_ProjectedClubDuesAssessmentSummarybyMembershipType '151','Nov 1, 2015'
 
-- =============================================
*/


---- Parse the ClubIDs into a temp table
CREATE Table #tmpList (StringField VARCHAR(50))
Exec ProcParseIntegerList @ClubIDs
Create Table #Clubs (ClubID INT)
Insert Into #Clubs(ClubID) Select StringField from #tmpList

/********  Foreign Currency Stuff ********/
DECLARE @ReportingCurrencyCode VARCHAR(15)
SET @ReportingCurrencyCode = 
(SELECT CASE WHEN COUNT(DISTINCT C.ValCurrencyCodeID) >=2 THEN 'USD' ELSE MAX(VCC.CurrencyCode) END AS ReportingCurrency
  FROM vClub C
  JOIN #Clubs ON C.ClubID = #Clubs.ClubID OR #Clubs.ClubID = 0
  JOIN vValCurrencyCode VCC ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID)

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
/***************************************/
 
-- total tax percentage for a given product and club 
CREATE TABLE #ClubProductTaxRate (
    ClubID INT, 
    ProductID INT, 
    TaxPercentage SMALLMONEY 
    )

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
    DuesSalesTax DECIMAL(10,2)
    )

INSERT INTO #FlexConversions
SELECT MembershipsConvertingToFlex.MembershipID,
       MembershipsConvertingToFlex.MembershipType,
       CASE WHEN CPTR.taxpercentage is null THEN MembershipsConvertingToFlex.AgreementPrice
            ELSE MembershipsConvertingToFlex.AgreementPrice + (MembershipsConvertingToFlex.AgreementPrice*CPTR.taxpercentage/100) 
       END DuesPrice,
       MembershipsConvertingToFlex.AgreementPrice AS DuesItemAmount, 
       CASE WHEN CPTR.taxpercentage is null THEN 0
            ELSE   MembershipsConvertingToFlex.AgreementPrice*CPTR.taxpercentage/100 
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
Left JOIN #ClubProductTaxRate CPTR 
   ON CPTR.ClubID = MS.ClubID 
   AND CPTR.ProductID = CP.ProductID 


---
---  Return all memberships to be assessed on the Projection assessment date, barring any
---  status changes before that time, taking into account and modifying the data for any 
---  conversion to a Flex Membership set to automatically occur before the assessment.
---  


SELECT 
       VR.Description AS RegionDescription, 
       C.ClubName, 
       C.ClubID,
       COALESCE(FC.MembershipType, P.Description) AS MembershipType, 
       @ReportingCurrencyCode as ReportingCurrencyCode,
       -- monthly dues count
       1 AS MembershipCount,       
       -- dues
       CASE WHEN FC.DuesPrice IS NOT NULL THEN (FC.DuesPrice * #PlanRate.PlanRate)
                WHEN CPTR.taxpercentage is null THEN (MS.CurrentPrice * #PlanRate.PlanRate)
                ELSE (MS.CurrentPrice + (MS.CurrentPrice*CPTR.taxpercentage/100))*#PlanRate.PlanRate
                END DuesPrice, 

       -- item amount       
       CASE WHEN FC.DuesItemAmount IS NOT NULL OR FC.DuesItemAmount<>0 THEN FC.DuesItemAmount * #PlanRate.PlanRate
                ELSE MS.CurrentPrice * #PlanRate.PlanRate
                END DuesItemAmount,

       -- salex tax       
       CASE WHEN FC.DuesSalesTax IS NOT NULL OR FC.DuesSalesTax<> 0 THEN FC.DuesSalesTax * #PlanRate.PlanRate
                WHEN CPTR.taxpercentage is null THEN 0 
                ELSE (MS.CurrentPrice * #PlanRate.PlanRate)*CPTR.taxpercentage/100 
                END DuesSalesTax, 

       CASE WHEN FC.DuesPrice IS NOT NULL THEN 0 
            WHEN JuniorDues.AssessableJrMembers IS NULL THEN 0
            ELSE JuniorDues.AssessableJrMembers
            END JuniorDuesCount,
       
      CASE WHEN FC.DuesPrice IS NOT NULL THEN 0
                WHEN JuniorDues.MembershipJrDues IS NULL THEN 0 
                WHEN CPTR_JM.taxpercentage is null THEN (JuniorDues.MembershipJrDues*#PlanRate.PlanRate) 
                ELSE (JuniorDues.MembershipJrDues*#PlanRate.PlanRate) + ((JuniorDues.MembershipJrDues * #PlanRate.PlanRate)* CPTR_JM.taxpercentage/100)
                END JuniorDuesPrice,

       -- junior itemamount       
       CASE WHEN FC.DuesPrice IS NOT NULL OR FC.DuesPrice<>0 THEN 0
                WHEN JuniorDues.MembershipJrDues IS NULL THEN 0
                ELSE (JuniorDues.MembershipJrDues * #PlanRate.PlanRate)
                END JuniorDuesItemAmount,

       -- junior sale tax       
       CASE WHEN FC.DuesPrice IS NOT NULL OR FC.DuesPrice<>0 THEN 0
                WHEN CPTR_JM.taxpercentage is null THEN 0
                ELSE (JuniorDues.MembershipJrDues * #PlanRate.PlanRate) * CPTR_JM.taxpercentage/100
                END JuniorDuesSalesTax,
       @ReportRunDateTime AS ReportRunDate, 
       @ProjectionAssessmentDate as ProjectionAssessmentDate,       
       Replace(Substring(convert(varchar,@ProjectionAssessmentDate,100),1,6)+', '+Substring(convert(varchar,@ProjectionAssessmentDate,100),8,4),'  ',' ') as ProjectionAssessmentDateHeader,
	   MS.ExpirationDate      
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
       ON C.ClubID = CP.ClubID
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
  --JOIN #ToUSDPlanRate
  --     ON VCC.CurrencyCode = #ToUSDPlanRate.FromCurrencyCode
  --    AND YEAR(@ProjectionAssessmentDate) = #ToUSDPlanRate.PlanYear
/*******************************************/   

  LEFT JOIN #ClubProductTaxRate CPTR 
       ON CPTR.ClubID = MS.ClubID 
       AND CPTR.ProductID = MT.ProductID    
  JOIN dbo.vValMembershipStatus VMS
       ON VMS.ValMembershipStatusID = MS.ValMembershipStatusID
  -- junior member 
  LEFT JOIN (Select Count(M.MemberID)as AssessableJrMembers, MPT.MembershipID,PT.ProductID, C.ClubID,
             Sum(PTP.Price)As MembershipJrDues
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
             Group by MPT.MembershipID,PT.ProductID, C.ClubID
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
SELECT 
       #Results.RegionDescription, 
       #Results.ClubName, 
       #Results.ClubID,
       #Results.MembershipType, 
       #Results.ReportingCurrencyCode,
       -- monthly dues count
       Sum(#Results.MembershipCount) AS MembershipCount,       
       -- dues
	   Sum(CASE WHEN IsNull(ExpirationDimDate.CalendarDate,'1/1/1900') = '1/1/1900'
	        THEN #Results.DuesPrice
			WHEN ExpirationDimDate.CalendarDate >= @LastDayOfProjectedAssessmentMonth
			THEN #Results.DuesPrice
			ELSE  (ExpirationDimDate.DayNumberInCalendarMonth / ExpirationDimDate.NumberOfDaysInMonth)* #Results.DuesPrice
			END) as Sum_DuesPrice, 

       -- item amount 
	   Sum(CASE WHEN IsNull(ExpirationDimDate.CalendarDate,'1/1/1900') = '1/1/1900'
	        THEN #Results.DuesItemAmount
			WHEN ExpirationDimDate.CalendarDate >= @LastDayOfProjectedAssessmentMonth
			THEN #Results.DuesItemAmount
			ELSE  (ExpirationDimDate.DayNumberInCalendarMonth / ExpirationDimDate.NumberOfDaysInMonth)* #Results.DuesItemAmount
			END) as DuesItemAmount,

       -- salex tax  
	   Sum(CASE WHEN IsNull(ExpirationDimDate.CalendarDate,'1/1/1900') = '1/1/1900'
	        THEN #Results.DuesSalesTax
			WHEN ExpirationDimDate.CalendarDate >= @LastDayOfProjectedAssessmentMonth
			THEN #Results.DuesSalesTax
			ELSE  (ExpirationDimDate.DayNumberInCalendarMonth / ExpirationDimDate.NumberOfDaysInMonth)* #Results.DuesSalesTax
			END) as DuesSalesTax,   

       Sum(#Results.JuniorDuesCount) as JuniorDuesCount,

	   Sum(CASE WHEN IsNull(ExpirationDimDate.CalendarDate,'1/1/1900') = '1/1/1900'
	        THEN #Results.JuniorDuesPrice
			WHEN ExpirationDimDate.CalendarDate >= @LastDayOfProjectedAssessmentMonth
			THEN #Results.JuniorDuesPrice
			ELSE  (ExpirationDimDate.DayNumberInCalendarMonth / ExpirationDimDate.NumberOfDaysInMonth)* #Results.JuniorDuesPrice
			END) as Sum_JuniorDuesPrice,  


       -- junior itemamount 
	   Sum(CASE WHEN IsNull(ExpirationDimDate.CalendarDate,'1/1/1900') = '1/1/1900'
	        THEN #Results.JuniorDuesItemAmount
			WHEN ExpirationDimDate.CalendarDate >= @LastDayOfProjectedAssessmentMonth
			THEN #Results.JuniorDuesItemAmount
			ELSE  (ExpirationDimDate.DayNumberInCalendarMonth / ExpirationDimDate.NumberOfDaysInMonth)* #Results.JuniorDuesItemAmount
			END) as JuniorDuesItemAmount, 

       -- junior sale tax 
	   Sum(CASE WHEN IsNull(ExpirationDimDate.CalendarDate,'1/1/1900') = '1/1/1900'
	        THEN #Results.JuniorDuesSalesTax
			WHEN ExpirationDimDate.CalendarDate >= @LastDayOfProjectedAssessmentMonth
			THEN #Results.JuniorDuesSalesTax
			ELSE  (ExpirationDimDate.DayNumberInCalendarMonth / ExpirationDimDate.NumberOfDaysInMonth)* #Results.JuniorDuesSalesTax
			END) as JuniorDuesSalesTax, 
			      
       #Results.ReportRunDate, 
       #Results.ProjectionAssessmentDate,       
       #Results.ProjectionAssessmentDateHeader       
       
  FROM #Results #Results
	 Left Join vReportDimDate ExpirationDimDate
	   ON #Results.ExpirationDate = ExpirationDimDate.CalendarDate  
	       
Group By #Results.RegionDescription, 
       #Results.ClubName, 
       #Results.ClubID,
       #Results.MembershipType, 
       #Results.ReportingCurrencyCode,
	   #Results.ReportRunDate, 
       #Results.ProjectionAssessmentDate,       
       #Results.ProjectionAssessmentDateHeader

 DROP TABLE #ClubProductTaxRate
 DROP TABLE #Clubs
 DROP TABLE #tmpList
 DROP TABLE #FlexConversions
 DROP TABLE #PlanRate
 DROP TABLE #ToUSDPlanRate
 DROP TABLE #Results




