


--
-- Returns the drawer activity for a single draweractivityid
--
-- parameters: a single draweractivityid integer
--  

-- EXEC mmsPosdrawer_POSDrawerDetail '214063'

CREATE PROC [dbo].[mmsPosdrawer_POSDrawerDetail] (
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

SELECT PDD.CloseDateTime, PDD.ClubName, PDD.DrawerActivityID, 
       PDD.PostDateTime as PostDateTime_Sort, 
	   PDD.MemberID, PDD.FirstName, 
       PDD.LastName, PDD.TranVoidedID, PDD.ReceiptNumber, 
       PDD.EmployeeID, PDD.DomainName, 
	   PDD.Quantity, 
       PDD.Sort, 
       PDD.Desc1, PDD.Desc2, PDD.Record, 
       E.LastName EmployeeLastname, E.FirstName EmployeeFirstname, DA.OpenDateTime, 
       PDD.DrawerStatusDescription, PDD.RegionDescription, 
       PDD.TranTypeDescription, PDD.DeptDescription, PDD.CardOnFileFlag,
/******  Foreign Currency Stuff  *********/
	   VCC.CurrencyCode as LocalCurrencyCode,
       #PlanRate.PlanRate,
       @ReportingCurrencyCode as ReportingCurrencyCode,
	   PDD.Amount * #PlanRate.PlanRate as Amount,	  
	   PDD.Amount as LocalCurrency_Amount,	   
	   PDD.Amount * #ToUSDPlanRate.PlanRate as USD_Amount,
	   PDD.Tax * #PlanRate.PlanRate as Tax,	  
	   PDD.Tax as LocalCurrency_Tax,	   
	   PDD.Tax * #ToUSDPlanRate.PlanRate as USD_Tax,
	   PDD.Total * #PlanRate.PlanRate as Total,	  
	   PDD.Total as LocalCurrency_Total,	   
	   PDD.Total * #ToUSDPlanRate.PlanRate as USD_Total,	   
	   PDD.TipAmount * #PlanRate.PlanRate as TipAmount,	  
	   PDD.TipAmount as LocalCurrency_TipAmount,	   
	   PDD.TipAmount * #ToUSDPlanRate.PlanRate as USD_TipAmount,	   
	   PDD.IssuanceAmount * #PlanRate.PlanRate as IssuanceAmount,	  
	   PDD.IssuanceAmount as LocalCurrency_IssuanceAmount,	   
	   PDD.IssuanceAmount * #ToUSDPlanRate.PlanRate as USD_IssuanceAmount,
	   PDD.ChangeRendered * #PlanRate.PlanRate as ChangeRendered,	  
	   PDD.ChangeRendered as LocalCurrency_ChangeRendered,	   
	   PDD.ChangeRendered * #ToUSDPlanRate.PlanRate as USD_ChangeRendered  
/***************************************/

  FROM dbo.vPOSDrawerDetail PDD
  JOIN dbo.vDrawerActivity DA
       ON PDD.DrawerActivityID = DA.DrawerActivityID  
/********** Foreign Currency Stuff **********/
  JOIN dbo.vDrawer DR
	   ON DA.DrawerID = DR.DrawerID
  JOIN dbo.vClub C
	   ON DR.ClubID = C.ClubID
  JOIN vValCurrencyCode VCC
       ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID
  JOIN #PlanRate
       ON VCC.CurrencyCode = #PlanRate.FromCurrencyCode
      AND YEAR(PDD.PostDateTime) = #PlanRate.PlanYear
  JOIN #ToUSDPlanRate
       ON VCC.CurrencyCode = #ToUSDPlanRate.FromCurrencyCode
      AND YEAR(PDD.PostDateTime) = #ToUSDPlanRate.PlanYear
/*******************************************/
  JOIN dbo.vEmployee E 
       ON PDD.EmployeeID = E.EmployeeID
 WHERE PDD.DrawerActivityID = @DrawerActivityID
 ORDER BY PDD.PostDateTime,
       PDD.Sort

DROP TABLE #PlanRate
DROP TABLE #ToUSDPlanRate

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END

