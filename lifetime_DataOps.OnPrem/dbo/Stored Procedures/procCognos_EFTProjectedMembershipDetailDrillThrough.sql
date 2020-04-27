


CREATE PROC [dbo].[procCognos_EFTProjectedMembershipDetailDrillThrough] (
  @ClubIDList VARCHAR(10),
  @ReportingCurrencyCode VARCHAR(15)
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON



-- =============================================
--	Object:			dbo.procCognos_EFTProjectedMembershipDetailDrillThrough
--	Author:			
--	Create date: 	10/15/2013
--	Description:	
--	Modified date:	
--	EXEC procCognos_EFTProjectedMembershipDetailDrillThrough '151', 'USD'
-- =============================================
DECLARE  @ReportRunDateTime VARCHAR(110) 
SET @ReportRunDateTime = Replace(SubString(Convert(Varchar,GetDate()),1,3)+' '+LTRIM(SubString(Convert(Varchar,GetDate()),5,DataLength(Convert(Varchar,GetDate()))-12)),' '+Convert(Varchar,Year(GetDate())),', '+Convert(Varchar,Year(GetDate()))) + '  ' + LTRIM(SubString(Convert(Varchar,GetDate(),22),10,5) + ' ' + Right(ConverT(Varchar,GetDate(),22),2))


CREATE TABLE #tmpList (StringField VARCHAR(50))
  CREATE TABLE #Clubs (ClubID VARCHAR(50))
  
   EXEC procParseStringList @ClubIDList
   INSERT INTO #Clubs (ClubID) SELECT StringField FROM #tmpList
   TRUNCATE TABLE #tmpList


/********  Foreign Currency Stuff ********/

CREATE TABLE #PlanRate (PlanRate DECIMAL(14,4), FromCurrencyCode VARCHAR(15), PlanYear INT)
INSERT INTO #PlanRate
SELECT PlanExchangeRate, FromCurrencyCode, PlanYear
FROM PlanExchangeRate
WHERE PlanYear = Year(GETDATE())
  AND ToCurrencyCode = @ReportingCurrencyCode

CREATE TABLE #ToUSDPlanRate (PlanRate DECIMAL(14,4), FromCurrencyCode VARCHAR(15), PlanYear INT)
INSERT INTO #ToUSDPlanRate
SELECT PlanExchangeRate, FromCurrencyCode, PlanYear
FROM PlanExchangeRate
WHERE PlanYear = Year(GETDATE())
  AND ToCurrencyCode = 'USD'


/***************************************/

SELECT VR.Description AS MMSRegion,
       C.ClubCode,
       C.ClubName, 
       CASE When VPT.Description is null
          THEN 'Undefined'
          ELSE VPT.Description
          END EFTPaymentMethod,
       EFTD.ExpirationDate AS AccountExpirationDate,
       M.MemberID, 
       M.FirstName,
	   M.LastName, 
	   VMS.Description MembershipStatus,
	   MS.CreatedDateTime AS MembershipCreatedDate,
	   M.JoinDate,
	   '('+MSP.AreaCode+') '+ SUBSTRING(MSP.Number,1,3)+'-'+SUBSTRING(MSP.Number,4,4)AS MembershipPhone,

/******  Foreign Currency Stuff  *********/
	   VCC.CurrencyCode as LocalCurrencyCode,
       #PlanRate.PlanRate,
       @ReportingCurrencyCode as ReportingCurrencyCode,	 
	   CASE WHEN VPT.Description is null
	       THEN 0
	       ELSE MSB.EFTAmount * #PlanRate.PlanRate 
	       END EFTAmount_Dues,
	   CASE WHEN VPT.Description is null
	       THEN 0
	       ELSE ISNull(MSB.EFTAmountProducts,0) * #PlanRate.PlanRate 
	       END EFTAmount_Products,	   
	   MSB.CurrentBalance * #PlanRate.PlanRate as CurrentBalance_Dues,
	   IsNull(MSB.CurrentBalanceProducts,0) * #PlanRate.PlanRate as CurrentBalance_Products,
	   CASE WHEN VPT.Description is null
	       THEN 0
	       ELSE MSB.EFTAmount
	       END LocalCurrency_EFTAmount_Dues,
	   CASE WHEN VPT.Description is null
	       THEN 0
	       ELSE IsNull(MSB.EFTAmountProducts,0)
	       END LocalCurrency_EFTAmount_Products,	   
	   MSB.CurrentBalance  as LocalCurrency_CurrentBalance_Dues,
	   IsNull(MSB.CurrentBalanceProducts,0)  as LocalCurrency_CurrentBalance_Products,
	   CASE WHEN VPT.Description is null
	       THEN 0
	       ELSE MSB.EFTAmount * #ToUSDPlanRate.PlanRate 
	       END USD_EFTAmount_Dues,
	   CASE WHEN VPT.Description is null
	       THEN 0
	       ELSE IsNull(MSB.EFTAmountProducts,0) * #ToUSDPlanRate.PlanRate 
	       END USD_EFTAmount_Products,
	   MSB.CurrentBalance * #ToUSDPlanRate.PlanRate as USD_CurrentBalance_Dues,
	   IsNull(MSB.CurrentBalanceProducts,0) * #ToUSDPlanRate.PlanRate as USD_CurrentBalance_Products,	   	   	
/***************************************/
       @ReportRunDateTime as ReportRunDateTime
       
FROM dbo.vClub C
JOIN #Clubs CS
     ON C.ClubID = CS.ClubID 
JOIN vMembership MS
     ON MS.ClubID = C.ClubID
JOIN dbo.vMember M
     ON MS.MembershipID = M.MembershipID
JOIN dbo.vValRegion VR
     ON C.ValRegionID = VR.ValRegionID 
JOIN dbo.vValMembershipStatus VMS
     ON MS.ValMembershipStatusID = VMS.ValMembershipStatusID
JOIN dbo.vMembershipBalance MSB
	ON MS.MembershipID = MSB.MembershipID

/********** Foreign Currency Stuff **********/
  JOIN vValCurrencyCode VCC
       ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID
  JOIN #PlanRate
       ON VCC.CurrencyCode = #PlanRate.FromCurrencyCode
      AND YEAR(GETDATE()) = #PlanRate.PlanYear
  JOIN #ToUSDPlanRate
       ON VCC.CurrencyCode = #ToUSDPlanRate.FromCurrencyCode
      AND YEAR(GETDATE()) = #ToUSDPlanRate.PlanYear
/*******************************************/
LEFT JOIN dbo.vPrimaryPhone PP
     ON PP.MembershipID = MS.MembershipID
LEFT JOIN dbo.vMembershipPhone MSP
     ON PP.MembershipID = MSP.MembershipID 
     AND PP.ValPhoneTypeID = MSP.ValPhoneTypeID
LEFT JOIN dbo.vEFTAccountDetail EFTD
     ON MS.MembershipID = EFTD.MembershipID
LEFT JOIN dbo.vValPaymentType VPT
     ON EFTD.ValPaymentTypeID = VPT.ValPaymentTypeID

WHERE M.ValMemberTypeID = 1 
     AND C.DisplayUIFlag = 1 
     AND MS.ValEFTOptionID = 1  ----- ValEFTOptionID of 1 = 'Active EFT'
	 AND ((IsNull(MSB.EFTAmount,0) + IsNull(MSB.EFTAmountProducts,0)) > 0)
Order by VPT.Description, M.MemberID
	  
    
  DROP TABLE #Clubs
  DROP TABLE #tmpList
  DROP TABLE #PlanRate
  DROP TABLE #ToUSDPlanRate

END


