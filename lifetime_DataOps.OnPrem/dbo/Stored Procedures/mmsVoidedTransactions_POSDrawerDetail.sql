



--
-- returns POS Drawer Detail information the Voided Transactions Brio document
--
-- Parameters: a list of club names and a start and end tranitem post date
--
-- exec mmsVoidedTransactions_POSDrawerDetail 'New Hope, MN','Apr 1, 2011','Apr 30, 2011', '-5'
-- 

CREATE PROC [dbo].[mmsVoidedTransactions_POSDrawerDetail] (
  @ClubList VARCHAR(1000),
  @PostStartDate SMALLDATETIME,
  @PostEndDate SMALLDATETIME,
  @EmployeeID INT
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON
CREATE TABLE #tmpList (StringField VARCHAR(50))
CREATE TABLE #Clubs (ClubName VARCHAR(50))

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

--INSERT INTO #Clubs EXEC procParseStringList @ClubList
   EXEC procParseStringList @ClubList
   INSERT INTO #Clubs (Clubname) SELECT StringField FROM #tmpList

/********  Foreign Currency Stuff ********/
DECLARE @ReportingCurrencyCode VARCHAR(15)
SET @ReportingCurrencyCode = 
(SELECT CASE WHEN COUNT(DISTINCT C.ValCurrencyCodeID) >=2 THEN 'USD' ELSE MAX(VCC.CurrencyCode) END AS ReportingCurrency
  FROM vClub C
  JOIN #Clubs ON C.ClubName = #Clubs.ClubName
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

SELECT POS.DrawerStatusDescription, POS.CloseDateTime, 
       POS.RegionDescription, POS.ClubName, POS.DrawerActivityID, 
       POS.PostDateTime as PostDateTime_Sort, 
	   Replace(Substring(convert(varchar,POS.PostDateTime,100),1,6)+', '+Substring(convert(varchar,POS.PostDateTime,100),8,10)+' '+Substring(convert(varchar,POS.PostDateTime,100),18,2),'  ',' ') as PostDateTime,              
	   POS.MemberID, POS.FirstName, POS.LastName, 
       POS.TranVoidedID, POS.ReceiptNumber, POS.EmployeeID, 
       POS.DomainName, E.FirstName EmplFirstname, E.LastName EmplLastname,
       POS.TranTypeDescription, POS.DeptDescription, POS.Quantity, 
       POS.Sort, POS.Desc1, 
       POS.Desc2, POS.Record, DA.OpenDateTime, 
       MMST.ReceiptComment, TV.VoidDateTime as VoidDateTime_Sort, 
	   Replace(Substring(convert(varchar,TV.VoidDateTime,100),1,6)+', '+Substring(convert(varchar,TV.VoidDateTime,100),8,10)+' '+Substring(convert(varchar,TV.VoidDateTime,100),18,2),'  ',' ') as VoidDateTime,              
	   TV.Comments VoidComments ,
/******  Foreign Currency Stuff  *********/
	   VCC.CurrencyCode as LocalCurrencyCode,
       #PlanRate.PlanRate,
       @ReportingCurrencyCode as ReportingCurrencyCode,
	   POS.Amount * #PlanRate.PlanRate as Amount,	  
	   POS.Amount as LocalCurrency_Amount,	  
	   POS.Amount * #ToUSDPlanRate.PlanRate as USD_Amount,
	   POS.Tax * #PlanRate.PlanRate as Tax,	  
	   POS.Tax as LocalCurrency_Tax,	  
	   POS.Tax * #ToUSDPlanRate.PlanRate as USD_Tax,		   
	   POS.Total * #PlanRate.PlanRate as Total,	  
	   POS.Total as LocalCurrency_Total,	  
	   POS.Total * #ToUSDPlanRate.PlanRate as USD_Total,	   		   
	   POS.ChangeRendered * #PlanRate.PlanRate as ChangeRendered,	  
	   POS.ChangeRendered as LocalCurrency_ChangeRendered,	  
	   POS.ChangeRendered * #ToUSDPlanRate.PlanRate as USD_ChangeRendered
/***************************************/

  FROM dbo.vDrawerActivity DA
  JOIN dbo.vPOSDrawerDetail POS
    ON DA.DrawerActivityID = POS.DrawerActivityID
  JOIN dbo.vTranVoided TV
    ON TV.TranVoidedID = POS.TranVoidedID
  JOIN dbo.vEmployee E
    ON E.EmployeeID = TV.EmployeeID
  JOIN dbo.vClub C
    ON POS.ClubName = C.ClubName
  JOIN #Clubs CS
    ON C.ClubName = CS.ClubName
/********** Foreign Currency Stuff **********/
  JOIN vValCurrencyCode VCC
       ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID
  JOIN #PlanRate
       ON VCC.CurrencyCode = #PlanRate.FromCurrencyCode
      AND YEAR(POS.PostDateTime) = #PlanRate.PlanYear
  JOIN #ToUSDPlanRate
       ON VCC.CurrencyCode = #ToUSDPlanRate.FromCurrencyCode
      AND YEAR(POS.PostDateTime) = #ToUSDPlanRate.PlanYear
/*******************************************/
  LEFT OUTER JOIN dbo.vMMSTran MMST
    ON POS.ReceiptNumber = MMST.ReceiptNumber
 WHERE --C.ClubName IN (SELECT ClubName FROM #Clubs)AND
       POS.PostDateTime BETWEEN @PostStartDate AND @PostEndDate AND 
       POS.TranVoidedID > 1 AND 
       ----POS.TranTypeDescription NOT IN ('Drop Cash', 'No Sale')
       POS.Sort <> 6 AND
       (TV.EmployeeID = @EmployeeID OR @EmployeeID IS NULL)
 			 

DROP TABLE #Clubs
DROP TABLE #tmpList
DROP TABLE #PlanRate
DROP TABLE #ToUSDPlanRate

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END

