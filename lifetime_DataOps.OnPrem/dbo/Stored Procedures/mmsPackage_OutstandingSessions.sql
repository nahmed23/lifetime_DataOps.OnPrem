

CREATE       PROCEDURE [dbo].[mmsPackage_OutstandingSessions](
            @ClubIDs VARCHAR(1000),
            @MMSDeptIDList VARCHAR(1000),
            @SaleYearMonth VARCHAR(10)
) 
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- EXEC mmsPackage_OutstandingSessions '141', '8|9'

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

IF @SaleYearMonth = ''
 BEGIN
     set @SaleYearMonth = '19000101'
 END
ELSE
 BEGIN
    set @SaleYearMonth = @SaleYearMonth + '01'
 END


CREATE TABLE #tmpList(StringField VARCHAR(50))

---- Parse the ClubIDs into a temp table
EXEC procParseIntegerList @ClubIDs
CREATE TABLE #Clubs(ClubID INT)
INSERT INTO #Clubs(ClubID) SELECT StringField FROM #tmpList

/********  Foreign Currency Stuff ********/
DECLARE @ReportingCurrencyCode VARCHAR(15)
SET @ReportingCurrencyCode = 
(SELECT CASE WHEN COUNT(DISTINCT C.ValCurrencyCodeID) >=2 THEN 'USD' ELSE MAX(VCC.CurrencyCode) END AS ReportingCurrency
  FROM vClub C
  JOIN #Clubs ON C.ClubID = #Clubs.ClubID
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

TRUNCATE TABLE #tmpList
CREATE TABLE #DepartmentIDs (DepartmentID INT)
IF @MMSDeptIDList = 'All'
 BEGIN
  INSERT INTO #DepartmentIDs (DepartmentID) SELECT DepartmentID FROM vDepartment
 END
ELSE
 BEGIN
  EXEC procParseIntegerList @MMSDeptIDList
  INSERT INTO #DepartmentIDs SELECT StringField FROM #tmpList
 END


SELECT C.ClubName AS SalesClubname, E.EmployeeID, E.FirstName AS EmployeeFirstname, 
E.LastName AS EmployeeLastname, PKG.CreatedDateTime as CreatedDateTime_Sort, 
Replace(Substring(convert(varchar,PKG.CreatedDateTime,100),1,6)+', '+Substring(convert(varchar,PKG.CreatedDateTime,100),8,10)+' '+Substring(convert(varchar,PKG.CreatedDateTime,100),18,2),'  ',' ') as CreatedDateTime,
PKG.SessionsLeft,  
M.MemberID, M.FirstName AS MemberFirstname, M.LastName AS MemberLastname, 
PKG.NumberOfSessions AS OriginalNumberOfSessions,P.Description AS ProductDescription,
GETDATE() AS ReportDate,PKG.Packageid, VPS.Description AS PackageStatusDescription,
VDS.Description AS DrawerStatusDescription, R.Description AS RegionDescription,
MSC.ClubName AS MembershipHomeClub,EC.ClubName AS EmployeeHomeClub, P.Productid,
 CASE
  WHEN P.Description LIKE '%30 minute%' ----- 30 minute session products
  THEN 1
  Else 0
 END Half_Session_Flag,
 D.Description AS Department,
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
JOIN #Clubs tC
    ON C.Clubid = tC.ClubID
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
  JOIN dbo.vDepartment D 
	 ON D.DepartmentID = P.DepartmentID 
  JOIN #DepartmentIDs
     ON D.DepartmentID = #DepartmentIDs.DepartmentID
WHERE  VPS.Description Not IN('Completed','Voided')
       AND PKG.CreatedDateTime >= convert(datetime, @SaleYearMonth, 101)

DROP TABLE #Clubs
DROP TABLE #tmpList
DROP TABLE #DepartmentIDs
DROP TABLE #PlanRate
DROP TABLE #ToUSDPlanRate

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END



