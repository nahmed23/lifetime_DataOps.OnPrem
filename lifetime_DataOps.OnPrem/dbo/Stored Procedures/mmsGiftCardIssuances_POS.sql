



-- EXEC mmsGiftCardIssuances_POS '141', 'Apr 1, 2011', 'Apr 25, 2011'

CREATE PROCEDURE [dbo].[mmsGiftCardIssuances_POS] (
  @ClubIDList VARCHAR(1000),
  @StartDate datetime,
  @EndDate datetime
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
  
  -- Parse the ClubIDs into a temp table
  EXEC procParseIntegerList @ClubIDList
  CREATE TABLE #Clubs (ClubID VARCHAR(50))
  INSERT INTO #Clubs (ClubID) SELECT StringField FROM #tmpList

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

SELECT 	TI.TranItemID, TI.ProductID,
		MMST.PostDateTime as PostDateTime_Sort, 
		Replace(Substring(convert(varchar,MMST.PostDateTime,100),1,6)+', '+Substring(convert(varchar,MMST.PostDateTime,100),8,10)+' '+Substring(convert(varchar,MMST.PostDateTime,100),18,2),'  ',' ') as PostDateTime,	
	    TI.Quantity, P.Description AS ProductDescription, 
		C.ClubID, C.ClubName, 
		E.EmployeeID EmployeeID, 
		E.FirstName EmpFirstName, 
		E.MiddleInt EmpMiddleName, 
		E.LastName EmpLastName, 
		M.MemberID, 
		M.FirstName MemFirstName, 
		M.MiddleName MemMiddleName, 
		M.LastName MemLastName,		
		ReceiptComment,
/******  Foreign Currency Stuff  *********/
	   VCC.CurrencyCode as LocalCurrencyCode,
       #PlanRate.PlanRate,
       @ReportingCurrencyCode as ReportingCurrencyCode,
	   TIGCI.IssuanceAmount * #PlanRate.PlanRate as IssuanceAmount,	  
	   TIGCI.IssuanceAmount as LocalCurrency_IssuanceAmount,	  
	   TIGCI.IssuanceAmount * #ToUSDPlanRate.PlanRate as USD_IssuanceAmount,
	   TI.ItemAmount * #PlanRate.PlanRate as ItemAmount,	  
	   TI.ItemAmount as LocalCurrency_ItemAmount,	  
	   TI.ItemAmount * #ToUSDPlanRate.PlanRate as USD_ItemAmount	  
/***************************************/

FROM vTranItemGiftCardIssuance TIGCI 
JOIN vTranItem TI
	ON TI.TranItemID=TIGCI.TranItemID 
JOIN vMMSTran MMST
	ON MMST.MMSTranID=TI.MMSTranID 
JOIN vProduct P
	ON TI.ProductID=P.ProductID 
JOIN vClub C 
	ON C.ClubID=MMST.ClubID
JOIN #Clubs tC
	ON tC.ClubID = C.ClubID
JOIN vDrawerActivity DA
	ON MMST.DrawerActivityID = DA.DrawerActivityID
JOIN vEmployee E 
	ON E.EmployeeID = MMST.EmployeeID
JOIN vMember M 
	ON M.MemberID = MMST.MemberID
/********** Foreign Currency Stuff **********/  
  JOIN vValCurrencyCode VCC
       ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID
  JOIN #PlanRate
       ON VCC.CurrencyCode = #PlanRate.FromCurrencyCode
      AND YEAR(MMST.PostDateTime) = #PlanRate.PlanYear
  JOIN #ToUSDPlanRate
       ON VCC.CurrencyCode = #ToUSDPlanRate.FromCurrencyCode
      AND YEAR(MMST.PostDateTime) = #ToUSDPlanRate.PlanYear
/*******************************************/

WHERE MMST.PostDateTime >= @StartDate 
      AND MMST.PostDateTime <= @EndDate 
	  AND MMST.TranVoidedID IS NULL 
      AND DA.ValDrawerStatusID = 3 --- Closed drawers only

DROP TABLE #PlanRate
DROP TABLE #ToUSDPlanRate

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END

