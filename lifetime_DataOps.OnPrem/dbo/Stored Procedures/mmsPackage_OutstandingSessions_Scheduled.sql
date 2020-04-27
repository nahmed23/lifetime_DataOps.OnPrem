




---- Returns listing of packages with outstanding sessions and related information
---- for all clubs


CREATE        PROCEDURE [dbo].[mmsPackage_OutstandingSessions_Scheduled] 
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON


-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

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

CREATE TABLE #ToUSDPlanRate (PlanRate DECIMAL(14,4), FromCurrencyCode VARCHAR(15), PlanYear INT)
INSERT INTO #ToUSDPlanRate
SELECT PlanExchangeRate, FromCurrencyCode, PlanYear
FROM PlanExchangeRate
WHERE ToCurrencyCode = 'USD'
/***************************************/

SELECT C.ClubName AS SalesClubname, E.EmployeeID, E.FirstName AS EmployeeFirstname, 
E.LastName AS EmployeeLastname, PKG.CreatedDateTime as CreatedDateTime_Sort, 
Replace(SubString(Convert(Varchar, PKG.CreatedDateTime),1,3)+' '+LTRIM(SubString(Convert(Varchar, PKG.CreatedDateTime),5,DataLength(Convert(Varchar, PKG.CreatedDateTime))-12)),' '+Convert(Varchar,Year(PKG.CreatedDateTime)),', '+Convert(Varchar,Year(PKG.CreatedDateTime))) as CreatedDateTime,
PKG.SessionsLeft, 
M.MemberID, M.FirstName AS MemberFirstname, M.LastName AS MemberLastname, 
PKG.NumberOfSessions AS OriginalNumberOfSessions,P.Description AS ProductDescription,
GETDATE() AS ReportDate,PKG.Packageid, VPS.Description AS PackageStatusDescription,
VDS.Description AS DrawerStatusDescription, R.Description AS RegionDescription,
MSC.ClubName AS MembershipHomeClub, EC.ClubName AS EmployeeHomeClub, P.Productid,
 CASE 
  WHEN P.Description LIKE '%30 minute%'  ---- 30 minute session products
  THEN 1
  ELSE 0
 END Half_Session_Flag,
/******  Foreign Currency Stuff  *********/
	   VCC.CurrencyCode as LocalCurrencyCode,
       #PlanRate.PlanRate,
       @ReportingCurrencyCode as ReportingCurrencyCode,
	   PKG.BalanceAmount * #PlanRate.PlanRate as BalanceAmount,
	   PKG.BalanceAmount as LocalCurrency_BalanceAmount,
	   PKG.BalanceAmount * #ToUSDPlanRate.PlanRate as USD_BalanceAmount	 
/***************************************/

FROM dbo.vPackage PKG
  JOIN dbo.vCLUB C
     ON C.ClubID=PKG.ClubID
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
  JOIN dbo.vValRegion R
     ON C.ValRegionID = R.ValRegionID
  JOIN dbo.vMember M
     ON M.MemberID=PKG.MemberID
  JOIN dbo.vMembership MS
     ON M.MembershipID = MS.MembershipID
  JOIN dbo.vCLUB MSC
     ON MS.ClubID = MSC.ClubID
  LEFT JOIN dbo.vEmployee E
     ON PKG.EmployeeID=E.EmployeeID
  LEFT JOIN dbo.vCLUB EC
     ON E.ClubID = EC.ClubID
  JOIN dbo.vProduct P
     ON PKG.ProductID=P.ProductID
  JOIN dbo.vValPackageStatus VPS
     ON PKG.ValPackageStatusID = VPS.ValPackageStatusID
  JOIN dbo.vMMSTran MT
     ON PKG.MMSTranID = MT.MMSTranID
  JOIN dbo.vDrawerActivity DA
     ON MT.DrawerActivityID = DA.DrawerActivityID
  JOIN dbo.vValDrawerStatus VDS
     ON DA.ValDrawerStatusID = VDS.ValDrawerStatusID

WHERE  VPS.Description Not IN('Completed','Voided')

DROP TABLE #PlanRate
DROP TABLE #ToUSDPlanRate


-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END


