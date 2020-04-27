



--
-- Returns batch information for batches closed within a selected date range for selected clubs.
--
-- Parameters: A club list and a batch closed date range 
-- EXEC mmsBatchReports_ClosedBatchStatus '151', 'Apr 1, 2011', 'Apr 11, 2011', 'FrontDeskPOS'
--
CREATE          PROC [dbo].[mmsBatchReports_ClosedBatchStatus] (
  @ClubList VARCHAR(1000),
  @CloseStartDate SMALLDATETIME,
  @CloseEndDate SMALLDATETIME,
  @TerminalNameList VARCHAR(1000)
  )
AS

BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY


CREATE TABLE #tmpList (StringField VARCHAR(15))
CREATE TABLE #Clubs (ClubID INT)

IF @ClubList <> 'All'
BEGIN

   EXEC procParseStringList @ClubList
   INSERT INTO #Clubs (ClubID) SELECT StringField FROM #tmpList
   TRUNCATE TABLE #tmpList
END
ELSE
BEGIN
   INSERT INTO #Clubs VALUES(0) --'All'
END

CREATE TABLE #TerminalNames (TerminalName VARCHAR(15))
BEGIN
	EXEC procParseStringList @TerminalNameList
    INSERT INTO #TerminalNames (TerminalName) SELECT StringField FROM #tmpList
    TRUNCATE TABLE #tmpList
END

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

SELECT CCTerm.Name AS TerminalName, CCTerm.ClubID, CCB.BatchNumber, CCB.OpenDateTime AS
       BatchOpendatetime, CCB.CloseDateTime AS BatchClosedatetime_Sort,
	   Replace(SubString(Convert(Varchar, CCB.CloseDateTime),1,3)+' '+LTRIM(SubString(Convert(Varchar, CCB.CloseDateTime),5,DataLength(Convert(Varchar, CCB.CloseDateTime))-12)),' '+Convert(Varchar,Year(CCB.CloseDateTime)),', '+Convert(Varchar,Year(CCB.CloseDateTime))) + ' ' + LTRIM(SubString(Convert(Varchar, CCB.CloseDateTime,22),10,5) + ' ' + Right(Convert(Varchar, CCB.CloseDateTime ,22),2)) as BatchClosedatetime,     
       CCB.SubmitDateTime AS BatchSubmitDatetime_Sort, 
	   Replace(SubString(Convert(Varchar, CCB.SubmitDateTime),1,3)+' '+LTRIM(SubString(Convert(Varchar, CCB.SubmitDateTime),5,DataLength(Convert(Varchar, CCB.SubmitDateTime))-12)),' '+Convert(Varchar,Year(CCB.SubmitDateTime)),', '+Convert(Varchar,Year(CCB.SubmitDateTime))) + ' ' + LTRIM(SubString(Convert(Varchar, CCB.SubmitDateTime,22),10,5) + ' ' + Right(Convert(Varchar, CCB.SubmitDateTime ,22),2)) as BatchSubmitDatetime,   	   
       CCBS.Description AS BatchStatus,
/******  Foreign Currency Stuff  *********/
	   VCC.CurrencyCode as LocalCurrencyCode,
       #PlanRate.PlanRate,
       @ReportingCurrencyCode as ReportingCurrencyCode,
	   CCB.NetAmount * #PlanRate.PlanRate as BatchNetAmount,	   
	   CCB.NetAmount as LocalCurrency_BatchNetAmount,	  
	   CCB.NetAmount * #ToUSDPlanRate.PlanRate as USD_BatchNetAmount	  	   	
/***************************************/
 
  FROM vPTCreditCardBatch CCB
  JOIN vPTCreditCardTerminal CCTerm
       ON CCB.PTCreditCardTerminalID = CCTerm.PTCreditCardTerminalID
  JOIN vValCreditCardBatchStatus  CCBS
       ON CCB.ValCreditCardBatchStatusID = CCBS.ValCreditCardBatchStatusID
  JOIN #Clubs CS
       ON CCTerm.ClubID = CS.ClubID OR CS.ClubID = 0 -- All
  JOIN #TerminalNames TN
       ON CCTerm.Name = TN.TerminalName
/********** Foreign Currency Stuff **********/
  JOIN vClub C 
	   ON CCTerm.ClubID = C.ClubID
  JOIN vValCurrencyCode VCC
       ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID
  JOIN #PlanRate
       ON VCC.CurrencyCode = #PlanRate.FromCurrencyCode
      AND YEAR(CCB.CloseDateTime) = #PlanRate.PlanYear
  JOIN #ToUSDPlanRate
       ON VCC.CurrencyCode = #ToUSDPlanRate.FromCurrencyCode
      AND YEAR(CCB.CloseDateTime) = #ToUSDPlanRate.PlanYear
/*******************************************/

 WHERE (CCB.CloseDateTime BETWEEN @CloseStartDate AND @CloseEndDate) 
    

DROP TABLE #tmpList
DROP TABLE #Clubs
DROP TABLE #TerminalNames
DROP TABLE #PlanRate
DROP TABLE #ToUSDPlanRate

-- Report Logging
UPDATE HyperionReportLog
SET EndDateTime = getdate()
WHERE ReportLogID = @Identity

END

