

--
-- returns Member purchasing counts originally used for the TargetMailingProgram Brio bqy
--
-- Parameters: a | separated list of clubnames, Product descriptions, and a start and end tran date
--
-- EXEC dbo.mmsTargetMailingProgram_ProductPurchases 'All', 'Basketball|Boxing|Court Rental|CPR Class|Experience Life|Life Guard Class|Non-Access Sports Membership - NASM|Racquet Balls|Racquetball|Squash|Squash Balls|Vertical Endeavor Initiation Fee|Vertical Endeavor Monthly Fee|Volleyball', 'Apr 1, 2011', 'Apr 5, 2011'
--Modified date:	4/11/2011 SC: added support for foreign currency

CREATE  PROC [dbo].[mmsTargetMailingProgram_ProductPurchases] (
  @ClubIDList VARCHAR(2000),
  @ProductList VARCHAR(1000),
  @TranStartDate SMALLDATETIME,
  @TranEndDate SMALLDATETIME
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
  CREATE TABLE #Clubs (ClubID VARCHAR(50))
IF @ClubIDList <> 'All'
BEGIN
   
   EXEC procParseStringList @ClubIDList
   INSERT INTO #Clubs (ClubID) SELECT StringField FROM #tmpList
   TRUNCATE TABLE #tmpList
END
ELSE
BEGIN
   INSERT INTO #Clubs VALUES (0) -- all clubs
END  

CREATE TABLE #Products (Description VARCHAR(50))
--INSERT INTO #Products EXEC procParseStringList @ProductList
  EXEC procParseStringList @ProductList
  INSERT INTO #Products (Description) SELECT StringField FROM #tmpList
  TRUNCATE TABLE  #tmpList

/********  Foreign Currency Stuff ********/
DECLARE @ReportingCurrencyCode VARCHAR(15)
SET @ReportingCurrencyCode = 
(SELECT CASE WHEN COUNT(DISTINCT C.ValCurrencyCodeID) >=2 THEN 'USD' ELSE MAX(VCC.CurrencyCode) END AS ReportingCurrency
  FROM vClub C
  JOIN #Clubs ON C.ClubID = #Clubs.ClubID OR #Clubs.ClubID = 0
  JOIN vValCurrencyCode VCC ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID)

CREATE TABLE #PlanRate (PlanRate DECIMAL(14,4), FromCurrencyCode VARCHAR(15), PlanYear INT)
INSERT INTO #PlanRate
SELECT PlanExchangeRate, FromCurrencyCode, PlanYear
FROM PlanExchangeRate
WHERE PlanYear >= Year(@TranStartDate)
  AND PlanYear <= Year(@TranEndDate)
  AND ToCurrencyCode = @ReportingCurrencyCode

CREATE TABLE #ToUSDPlanRate (PlanRate DECIMAL(14,4), FromCurrencyCode VARCHAR(15), PlanYear INT)
INSERT INTO #ToUSDPlanRate
SELECT PlanExchangeRate, FromCurrencyCode, PlanYear
FROM PlanExchangeRate
WHERE PlanYear >= Year(@TranStartDate)
  AND PlanYear <= Year(@TranEndDate)
  AND ToCurrencyCode = 'USD'
/***************************************/

 SELECT MMST.MemberID, MMST.MembershipID, M.FirstName,
       M.LastName, SUM ( TI.Quantity ) Quantity,        
/******  Foreign Currency Stuff  *********/
	   VCC.CurrencyCode as LocalCurrencyCode,
       #PlanRate.PlanRate,
       @ReportingCurrencyCode as ReportingCurrencyCode,
	   SUM ( TI.ItemAmount * #PlanRate.PlanRate) as ItemAmount,
	   SUM ( TI.ItemAmount ) as LocalCurrency_ItemAmount,
	   SUM ( TI.ItemAmount * #ToUSDPlanRate.PlanRate) as USD_ItemAmount	   	   	
/***************************************/

  FROM dbo.vMMSTran MMST
  JOIN dbo.vTranItem TI
       ON MMST.MMSTranID = TI.MMSTranID
  JOIN dbo.vProduct P
       ON TI.ProductID = P.ProductID
  JOIN dbo.vMember M
       ON M.MemberID = MMST.MemberID
  JOIN dbo.vMembership MS
       ON MMST.MembershipID = MS.MembershipID
  JOIN dbo.vValMembershipStatus VMS 
       ON MS.ValMembershipStatusID = VMS.ValMembershipStatusID
  JOIN dbo.vClub C
       ON C.ClubID = MS.ClubID
  JOIN #Clubs CS 
       ON C.ClubID = CS.ClubID or CS.ClubID = 0
--       ON C.ClubName = CS.ClubName
  JOIN #Products PS 
       ON P.Description = PS.Description
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

 WHERE MMST.PostDateTime BETWEEN @TranStartDate AND @TranEndDate AND
       VMS.Description = 'Active' AND
       MMST.TranVoidedID IS NULL AND
       M.ActiveFlag = 1
 GROUP BY MMST.MemberID, MMST.MembershipID, M.FirstName, M.LastName, VCC.CurrencyCode, #PlanRate.PlanRate

DROP TABLE #Clubs
DROP TABLE #Products
DROP TABLE #tmpList
DROP TABLE #PlanRate
DROP TABLE #ToUSDPlanRate

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END

