


--
-- returns Club, Product, Price and Produst Status information for the Product/Price Brio document.
--
-- Parameters: a list of club names and a list of department names
-- EXEC mmsClubProduct '141', 'Personal Training'
CREATE    PROC [dbo].[mmsClubProduct] (
  @ClubIDList VARCHAR(2000),
  @DeptList VARCHAR(1000)
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

CREATE TABLE #tmpList (StringField VARCHAR(50))
CREATE TABLE #Clubs (ClubID VARCHAR(15))
EXEC procParseStringList @ClubIDList
INSERT INTO #Clubs (ClubID) SELECT StringField FROM #tmpList
TRUNCATE TABLE #tmpList

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

CREATE TABLE #Depts (Department VARCHAR(50))
EXEC procParseStringList @DeptList
INSERT INTO #Depts (Department) SELECT StringField FROM #tmpList
TRUNCATE TABLE #tmpList

SELECT R.Description AS RegionDescription, C.ClubName, P.Description AS ProductDescription,
       D.Description AS DeptDescription, 
       COMM.Description AS CommissionableDescription, T.TaxPercentage, T.ProductID, 
       P.GLAccountNumber, P.GLSubAccountNumber, P.GLOverRideClubID, C.GLClubID,
       G.Description AS GLGroupDescription,P.DisplayUIFlag AS ProductUIDisplay,
       P.EndDate AS ProductEndDate, GETDATE()AS ReportDate, VPS.Description AS ProductStatus,
/******  Foreign Currency Stuff  *********/
	   VCC.CurrencyCode as LocalCurrencyCode,
       #PlanRate.PlanRate,
       @ReportingCurrencyCode as ReportingCurrencyCode,
	   CP.Price * #PlanRate.PlanRate as Price,	  
	   CP.Price as LocalCurrency_Price,	  
	   CP.Price * #ToUSDPlanRate.PlanRate as USD_Price,
	   CPP.Price * #PlanRate.PlanRate as PKPrice,	  
	   CPP.Price as LocalCurrency_PKPrice,	  
	   CPP.Price * #ToUSDPlanRate.PlanRate as USD_PKPrice,
/***************************************/
       CASE WHEN CP.SoldInPK = 1 THEN 'Yes' ELSE 'No' END SoldInPK
  FROM dbo.vClub C
  JOIN #Clubs CS 
    ON C.ClubID = CS.ClubID
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
    ON R.ValRegionID = C.ValRegionID
  JOIN dbo.vClubProduct CP
    ON C.ClubID = CP.ClubID
  JOIN dbo.vProduct P
    ON CP.ProductID = P.ProductID
  JOIN dbo.vValProductStatus VPS 
    ON VPS.ValProductStatusID = P.ValProductStatusID 
  JOIN dbo.vDepartment D
    ON P.DepartmentID = D.DepartmentID
  JOIN #Depts DS
    ON D.Description = DS.DEPARTMENT
  JOIN dbo.vValCommissionable COMM
    ON CP.ValCommissionableID = COMM.ValCommissionableID
  JOIN dbo.vClubProductPriceTax T
    ON (CP.ClubID = T.ClubID AND CP.ProductID = T.ProductID)
  JOIN dbo.vValGLGroup G
    ON P.ValGLGroupID = G.ValGLGroupID
  LEFT OUTER JOIN dbo.vClubProductPKPrice CPP 
    ON (CP.ClubID = CPP.ClubID AND CP.ProductID = CPP.ProductID) 

DROP TABLE #Clubs
DROP TABLE #Depts
DROP TABLE #tmpList
DROP TABLE #PlanRate
DROP TABLE #ToUSDPlanRate

-- Report Logging
UPDATE HyperionReportLog
SET EndDateTime = getdate()
WHERE ReportLogID = @Identity

END


