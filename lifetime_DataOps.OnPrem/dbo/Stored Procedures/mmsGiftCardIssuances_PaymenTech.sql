


--
-- This query returns a listing of all gift cards issued for selected clubs within a
-- selected date range ( from closed drawers and not voided )
-- based upon data in the PaymenTech stored value card transaction table
-- EXEC mmsGiftCardIssuances_PaymenTech '141', 'Apr 1, 2011', 'Apr 25, 2011'

CREATE  PROCEDURE [dbo].[mmsGiftCardIssuances_PaymenTech] (
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

SELECT SVCT.TransactionDateTime, CCT.ClubID, CCT.Description AS CreditCardTerminal, 
SVCT.PTStoredValueCardTransactionID, SVCT.VoidedFlag, SVCT.EmployeeID, E.FirstName, E.LastName,
/******  Foreign Currency Stuff  *********/
	   VCC.CurrencyCode as LocalCurrencyCode,
       #PlanRate.PlanRate,
       @ReportingCurrencyCode as ReportingCurrencyCode,
	   SVCT.TranAmount * #PlanRate.PlanRate as TranAmount,	  
	   SVCT.TranAmount as LocalCurrency_TranAmount,	  
	   SVCT.TranAmount * #ToUSDPlanRate.PlanRate as USD_TranAmount   
/***************************************/

FROM vPTStoredValueCardTransaction SVCT
 JOIN vPTCreditCardBatch CCB
 ON SVCT.PTCreditCardBatchID=CCB.PTCreditCardBatchID
 JOIN vPTCreditCardTerminal CCT
 ON CCB.PTCreditCardTerminalID=CCT.PTCreditCardTerminalID
 JOIN #Clubs tC
 ON tC.ClubID = CCT.ClubID
 JOIN vDrawerActivity DA
 ON CCB.DrawerActivityID=DA.DrawerActivityID
 JOIN vEmployee E
 ON SVCT.EmployeeID=E.EmployeeID
/********** Foreign Currency Stuff **********/
  JOIN vClub C
	   ON CCT.ClubID = C.ClubID
  JOIN vValCurrencyCode VCC
       ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID
  JOIN #PlanRate
       ON VCC.CurrencyCode = #PlanRate.FromCurrencyCode
      AND YEAR(SVCT.TransactionDateTime) = #PlanRate.PlanYear
  JOIN #ToUSDPlanRate
       ON VCC.CurrencyCode = #ToUSDPlanRate.FromCurrencyCode
      AND YEAR(SVCT.TransactionDateTime) = #ToUSDPlanRate.PlanYear
/*******************************************/

WHERE SVCT.TransactionCode=70 ----- Issuances Only
  AND DA.ValDrawerStatusID=3  ----- Closed Drawers Only
  AND SVCT.TransactionDateTime >= @StartDate 
  AND SVCT.TransactionDateTime <= @EndDate
  AND SVCT.VoidedFlag=0

DROP TABLE #PlanRate
DROP TABLE #ToUSDPlanRate

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END

