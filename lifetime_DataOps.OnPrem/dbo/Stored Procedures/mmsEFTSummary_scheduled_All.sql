
CREATE PROC [dbo].[mmsEFTSummary_scheduled_All] 

AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

--EXEC mmsEFTSummary_scheduled_All

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

--First moment, first of the month
DECLARE @StartDate DATETIME
SET @StartDate = DATEADD(mm,DATEDIFF(mm,0,GETDATE()),0)

--First moment, third of the month
DECLARE @EndDate DATETIME
SET @EndDate = DATEADD(dd,2,@StartDate)

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
WHERE PlanYear >= Year(@StartDate)
  AND PlanYear <= Year(@EndDate)
  AND ToCurrencyCode = @ReportingCurrencyCode

CREATE TABLE #ToUSDPlanRate (PlanRate DECIMAL(14,4), FromCurrencyCode VARCHAR(15), PlanYear INT)
INSERT INTO #ToUSDPlanRate
SELECT PlanExchangeRate, FromCurrencyCode, PlanYear
FROM PlanExchangeRate
WHERE PlanYear >= Year(@StartDate)
  AND PlanYear <= Year(@EndDate)
  AND ToCurrencyCode = 'USD'

/***************************************/

SELECT C.ClubName, 
       VR.Description AS RegionDescription, 
       EFT.ValPaymentTypeID, 	 
       VPT.Description AS PaymentTypeDescription,  
       EFT.ValEFTStatusID,
       VES.Description AS EFTStatusDescription,
       C.GLClubID,
       COUNT(1) TransactionCount,	   
       COUNT(CASE WHEN EFT.ValEFTStatusID = 2 THEN 1 ELSE NULL END) ReturnedCount,       
       COUNT(CASE WHEN EFT.ValEFTStatusID = 3 THEN 1 ELSE NULL END) ApprovedCount,
	   @StartDate AS Report_StartDate,
	   @EndDate AS Report_EndDate,
/******  Foreign Currency Stuff  *********/
	   VCC.CurrencyCode as LocalCurrencyCode,
       #PlanRate.PlanRate,
       @ReportingCurrencyCode as ReportingCurrencyCode,
	   SUM(EFT.EFTAmount * #PlanRate.PlanRate) as EFTAmount, 
	   SUM(EFT.EFTAmount) as LocalCurrency_EFTAmount, 	       
	   SUM(EFT.EFTAmount * #ToUSDPlanRate.PlanRate) as USD_EFTAmount,
	   SUM(CASE WHEN EFT.ValEFTStatusID = 2 THEN EFT.EFTAmount * #PlanRate.PlanRate ELSE 0 END) as ReturnedAmount,  	
	   SUM(CASE WHEN EFT.ValEFTStatusID = 2 THEN EFT.EFTAmount ELSE 0 END) LocalCurrency_ReturnedAmount,       
         SUM(CASE WHEN EFT.ValEFTStatusID = 2 THEN EFT.EFTAmount * #ToUSDPlanRate.PlanRate ELSE 0 END) as USD_ReturnedAmount,	   
	   SUM(CASE WHEN EFT.ValEFTStatusID = 3 THEN EFT.EFTAmount * #PlanRate.PlanRate ELSE 0 END) as ApprovedAmount,
	   SUM(CASE WHEN EFT.ValEFTStatusID = 3 THEN EFT.EFTAmount ELSE 0 END) as LocalCurrency_ApprovedAmount,
         SUM(CASE WHEN EFT.ValEFTStatusID = 3 THEN EFT.EFTAmount * #ToUSDPlanRate.PlanRate ELSE 0 END) as USD_ApprovedAmount	
/***************************************/
                                                           
  FROM vMembership MS
  JOIN dbo.vClub C
       ON C.ClubID = MS.ClubID
  JOIN dbo.vValRegion VR
       ON C.ValRegionID = VR.ValRegionID
  JOIN dbo.vEFT EFT
       ON EFT.MembershipID = MS.MembershipID
  JOIN dbo.vValPaymentType VPT
       ON EFT.ValPaymentTypeID = VPT.ValPaymentTypeID
  JOIN dbo.vValEFTStatus VES
       ON EFT.ValEFTStatusID = VES.ValEFTStatusID
  JOIN dbo.vMembershipBalance MSB
       ON MS.MembershipID = MSB.MembershipID
  JOIN dbo.vMember M 
       ON MS.MembershipID = M.MembershipID
/********** Foreign Currency Stuff **********/
  JOIN vValCurrencyCode VCC
       ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID
  JOIN #PlanRate
       ON VCC.CurrencyCode = #PlanRate.FromCurrencyCode
      AND YEAR(EFT.EFTDate) = #PlanRate.PlanYear
  JOIN #ToUSDPlanRate
       ON VCC.CurrencyCode = #ToUSDPlanRate.FromCurrencyCode
      AND YEAR(EFT.EFTDate) = #ToUSDPlanRate.PlanYear
/*******************************************/
 WHERE C.DisplayUIFlag = 1 
   AND EFT.EFTDate >= @StartDate
   AND EFT.EFTDate < @EndDate --Only First 2 days of the month
   AND VPT.ViewBankAccountTypeFlag = 1
   AND M.ValMemberTypeID = 1
   AND EFT.EFTReturnCodeID <> 42
   AND EFT.EFTReturnCodeID IS NOT NULL
GROUP BY C.ClubName, VR.Description, EFT.ValPaymentTypeID, VPT.Description, C.GLClubID, VES.Description, EFT.ValEFTStatusID, VCC.CurrencyCode, #PlanRate.PlanRate
Order By VR.Description,C.ClubName

DROP TABLE #PlanRate
DROP TABLE #ToUSDPlanRate

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END

