


----- Returns Card On File and Card Present transactions, summarized by date, for batches 
----- closed within a selected date range 
----- Parameters: Batch Close date range, terminal location
-- EXEC mmsDailyDeposit_CardOnFile 'Apr 1, 2011', 'Apr 2, 2011', 'FrontDeskPOS'

CREATE     PROC [dbo].[mmsDailyDeposit_CardOnFile] (
 @CloseStartDate SMALLDATETIME,
 @CloseEndDate  SMALLDATETIME,
 @Location VARCHAR(100)
)

AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

  CREATE TABLE #tmpList (StringField VARCHAR(50))

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY
  
  -- Parse the Locations into a temp table
  EXEC procParseStringList @Location
  CREATE TABLE #Locations (Location VARCHAR(50))
  INSERT INTO #Locations (Location) SELECT StringField FROM #tmpList

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
WHERE PlanYear >= Year(@CloseStartDate)
  AND PlanYear <= Year(@CloseEndDate)
  AND ToCurrencyCode = @ReportingCurrencyCode

CREATE TABLE #ToUSDPlanRate (PlanRate DECIMAL(14,4), FromCurrencyCode VARCHAR(15), PlanYear INT)
INSERT INTO #ToUSDPlanRate
SELECT PlanExchangeRate, FromCurrencyCode, PlanYear
FROM PlanExchangeRate
WHERE PlanYear >= Year(@CloseStartDate)
  AND PlanYear <= Year(@CloseEndDate)
  AND ToCurrencyCode = 'USD'
/***************************************/

SELECT TRN.PTCreditCardBatchID, CONVERT(VARCHAR(10), B.CloseDateTime, 101) AS ClosedDate, 
 TRN.CardType, TRN.CardOnFileFlag, TERM.ClubID, TERM.TerminalNumber, 
 B.BatchNumber, CCBS.Description AS Status, TERM.Name AS TerminalName, B.SubmitDateTime as SubmitDateTime_Sort,
 Replace(SubString(Convert(Varchar, B.SubmitDateTime),1,3)+' '+LTRIM(SubString(Convert(Varchar, B.SubmitDateTime),5,DataLength(Convert(Varchar, B.SubmitDateTime))-12)),' '+Convert(Varchar,Year(B.SubmitDateTime)),', '+Convert(Varchar,Year(B.SubmitDateTime))) + ' ' + LTRIM(SubString(Convert(Varchar, B.SubmitDateTime,22),10,5) + ' ' + Right(Convert(Varchar, B.SubmitDateTime ,22),2)) as SubmitDateTime,    
 B.DrawerActivityID,
/******  Foreign Currency Stuff  *********/
	   VCC.CurrencyCode as LocalCurrencyCode,
       #PlanRate.PlanRate,
       @ReportingCurrencyCode as ReportingCurrencyCode,
	   Sum(TRN.TranAmount * #PlanRate.PlanRate) as TranAmount,	   
	   Sum(TRN.TranAmount) as LocalCurrency_TranAmount,	   
	   Sum(TRN.TranAmount * #ToUSDPlanRate.PlanRate) as USD_TranAmount	  	
/***************************************/

FROM dbo.vPTCreditCardBatch B 
  JOIN dbo.vPTCreditCardTransaction TRN
     ON B.PTCreditCardBatchID = TRN.PTCreditCardBatchID
  JOIN dbo.vPTCreditCardTerminal TERM
     ON TERM.PTCreditCardTerminalID = B.PTCreditCardTerminalID
  JOIN dbo.vValCreditCardBatchStatus CCBS 
     ON CCBS.ValCreditCardBatchStatusID = B.ValCreditCardBatchStatusID
/********** Foreign Currency Stuff **********/
  JOIN dbo.vClub C
	   ON TERM.ClubID = C.ClubID
  JOIN vValCurrencyCode VCC
       ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID
  JOIN #PlanRate
       ON VCC.CurrencyCode = #PlanRate.FromCurrencyCode
      AND YEAR(B.CloseDateTime) = #PlanRate.PlanYear
  JOIN #ToUSDPlanRate
       ON VCC.CurrencyCode = #ToUSDPlanRate.FromCurrencyCode
      AND YEAR(B.CloseDateTime) = #ToUSDPlanRate.PlanYear
/*******************************************/
  JOIN #Locations L
     ON TERM.Name = L.Location
WHERE  B.CloseDateTime >= @CloseStartDate AND
              B.CloseDateTime <= @CloseEndDate AND 
              TRN.VoidedFlag = 0 AND 
             (NOT (TRN.TransactionCode = 2) OR TRN.TransactionCode IS NULL)  
GROUP BY TRN.PTCreditCardBatchID, CONVERT(VARCHAR(10), B.CloseDateTime, 101), 
 TRN.CardType, TRN.CardOnFileFlag, TERM.ClubID, TERM.TerminalNumber, 
 B.BatchNumber, CCBS.Description, TERM.Name, B.SubmitDateTime, B.DrawerActivityID, VCC.CurrencyCode, #PlanRate.PlanRate

  DROP TABLE #Locations
  DROP TABLE #tmpList
  DROP TABLE #PlanRate
  DROP TABLE #ToUSDPlanRate

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END

