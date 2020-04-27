

CREATE    PROC [dbo].[mmsPosdrawer_AllocationOfTendered] (
  @DrawerActivityID INT
  )
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
DECLARE @Identity AS INT
INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
SET @Identity = @@IDENTITY

DECLARE @ClubID INT
SELECT @ClubID = C.ClubID
FROM vClub C
JOIN vDrawer D ON C.ClubID = D.ClubID
JOIN vDrawerActivity DA ON D.DrawerID = DA.DrawerID
WHERE DA.DrawerActivityID = @DrawerActivityID

/********  Foreign Currency Stuff ********/
DECLARE @ReportingCurrencyCode VARCHAR(15)
SET @ReportingCurrencyCode = 
(SELECT CASE WHEN COUNT(DISTINCT C.ValCurrencyCodeID) >=2 THEN 'USD' ELSE MAX(VCC.CurrencyCode) END AS ReportingCurrency
  FROM vClub C 
  JOIN vValCurrencyCode VCC ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID
  WHERE C.ClubID = @ClubID)

CREATE TABLE #PlanRate (PlanRate DECIMAL(14,4), FromCurrencyCode VARCHAR(15), PlanYear INT)
INSERT INTO #PlanRate
SELECT PlanExchangeRate, FromCurrencyCode, PlanYear
FROM PlanExchangeRate
WHERE ToCurrencyCode = @ReportingCurrencyCode

CREATE TABLE #ToUSDPlanRate (PlanRate DECIMAL(14,4), FromCurrencyCode VARCHAR(15), PlanYear INT)
INSERT INTO #ToUSDPlanRate
SELECT PlanExchangeRate, FromCurrencyCode, PlanYear
FROM PlanExchangeRate
WHERE ToCurrencyCode = 'USD'
/***************************************/

SELECT DAA.DrawerActivityID, VPT.ValPaymentTypeID, 
       VPT.Description PaymentDescription, VPT.SortOrder, 
       C.ClubName, VR.Description RegionDescription,
/******  Foreign Currency Stuff  *********/
	   VCC.CurrencyCode as LocalCurrencyCode,
       #PlanRate.PlanRate,
       @ReportingCurrencyCode as ReportingCurrencyCode,
	   DAA.ActualTotalAmount * #PlanRate.PlanRate as ActualTotalAmount,	   
	   DAA.ActualTotalAmount as LocalCurrency_ActualTotalAmount,	   
	   DAA.ActualTotalAmount * #ToUSDPlanRate.PlanRate as USD_ActualTotalAmount  	   	
/***************************************/

FROM dbo.vDrawerActivityAmount DAA
  JOIN dbo.vDrawerActivity DA
       ON DAA.DrawerActivityID = DA.DrawerActivityID
  JOIN dbo.vDrawer D
       ON DA.DrawerID = D.DrawerID
  JOIN dbo.vClub C
       ON D.ClubID = C.ClubID
/********** Foreign Currency Stuff **********/
  JOIN vValCurrencyCode VCC
       ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID
  JOIN #PlanRate
       ON VCC.CurrencyCode = #PlanRate.FromCurrencyCode
      AND YEAR(DA.CloseDateTime) = #PlanRate.PlanYear
  JOIN #ToUSDPlanRate
       ON VCC.CurrencyCode = #ToUSDPlanRate.FromCurrencyCode
      AND YEAR(DA.CloseDateTime) = #ToUSDPlanRate.PlanYear
/*******************************************/
  JOIN dbo.vValRegion VR
       ON C.ValRegionID = VR.ValRegionID
  RIGHT OUTER JOIN dbo.vValPaymentType VPT 
       ON VPT.ValPaymentTypeID = DAA.ValPaymentTypeID
  WHERE VPT.Description <> 'Charge to Account' AND 
       DAA.DrawerActivityID = @DrawerActivityID
  ORDER BY VPT.SortOrder

DROP TABLE #PlanRate
DROP TABLE #ToUSDPlanRate

-- Report Logging
UPDATE HyperionReportLog
SET EndDateTime = getdate()
WHERE ReportLogID = @Identity


END

