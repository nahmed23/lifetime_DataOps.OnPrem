

/*--
-- Returns batch information for batches closed within a selected date range for selected clubs.
--
-- Parameters: A club list and a batch closed date range 

EXEC procCognos_ClosedBatchStatus '205', 'Feb 1, 2013', 'Feb 28, 2013', 
--EXEC procCognos_ClosedBatchStatus '13', 'Feb 1, 2012', 'sep 28, 2012', 
'Terminalname|AquaticsPOS|Cafe/BistroPOS|CorpMembRelPOS|ECommercePOS|FrontDeskPOS|HBCPos|InterimSalonPOS|InterimSpaPOS|MartiniBluPOS|MemberActPOS|PersTrainPOS|ProShop|ProShopPOS|SpaBizPOS|TennisDeskPOS',
--'SpaBizPOS',
'Non Submitted'
'Closed'

select * from vclub where clubname like 'Miss%'
-- */

create          PROC [dbo].[procCognos_ClosedBatchStatus] (
  @ClubList VARCHAR(1000),
  @CloseStartDate SMALLDATETIME,
  @CloseEndDate SMALLDATETIME,
  @TerminalNameList VARCHAR(1000),
  @BatchStatus VARCHAR(15)
  )
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON


DECLARE @HeaderDateRange VARCHAR(33), @ReportRunDateTime VARCHAR(21) 
SET @HeaderDateRange = convert(varchar(12), @CloseStartDate, 107) + ' to ' + convert(varchar(12), @CloseEndDate, 107)
SET @ReportRunDateTime = Replace(Substring(convert(varchar,getdate(),100),1,6)+', '+Substring(convert(varchar,GETDATE(),100),8,10)+' '+Substring(convert(varchar,getdate(),100),18,2),'  ',' ')

DECLARE @HeaderLocationList VARCHAR(1000)
SET @HeaderLocationList = REPLACE(@TerminalNameList, '|',', ')


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

SET @CloseEndDate = DATEADD(DD,1,@CloseEndDate) -- includes data for a full day

SELECT CCTerm.Name AS TerminalName, CCTerm.ClubID, C.ClubName, R.Description AS Region, CCB.BatchNumber, CCB.OpenDateTime AS
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
	   CCB.NetAmount * #ToUSDPlanRate.PlanRate as USD_BatchNetAmount,	   	  	   	
/***************************************/
 
  @HeaderDateRange AS HeaderDateRange,
  @ReportRunDateTime AS ReportRunDateTime,
  @HeaderLocationList AS HeaderLocationList,
  CASE WHEN CCB.SubmitDateTime IS NULL THEN 'Non Submitted'  ELSE 'Closed' END AS BatchStatus_ClosedNonSubmitted

  INTO #Results
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
  JOIN vValRegion R 
       ON R.ValRegionID = C.ValRegionID 	   
  JOIN vValCurrencyCode VCC
       ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID
  JOIN #PlanRate
       ON VCC.CurrencyCode = #PlanRate.FromCurrencyCode
      AND YEAR(CCB.CloseDateTime) = #PlanRate.PlanYear
  JOIN #ToUSDPlanRate
       ON VCC.CurrencyCode = #ToUSDPlanRate.FromCurrencyCode
      AND YEAR(CCB.CloseDateTime) = #ToUSDPlanRate.PlanYear
/*******************************************/

 WHERE CCB.CloseDateTime>= @CloseStartDate AND CCB.CloseDateTime < @CloseEndDate
    
	SELECT 
		TerminalName, 
		ClubID, 
		ClubName,
		Region, 
		BatchNumber, 
		BatchOpendatetime, 
		BatchClosedatetime_Sort,	   
		BatchClosedatetime,     
		BatchSubmitDatetime_Sort, 
		BatchSubmitDatetime,   	   
		BatchStatus,
		LocalCurrencyCode,
		PlanRate,
		ReportingCurrencyCode,
		BatchNetAmount,	   
		LocalCurrency_BatchNetAmount,	  
		USD_BatchNetAmount,	   	  	   	
		HeaderDateRange,
		ReportRunDateTime,
		HeaderLocationList,
		BatchStatus_ClosedNonSubmitted	  
	FROM( SELECT *, max_BatchClosedatetime_Sort = MAX(BatchClosedatetime_Sort) OVER (PARTITION BY TerminalName , ClubID, Region, BatchNumber)
		  FROM #Results ) AS T1 	
	WHERE BatchStatus_ClosedNonSubmitted = @BatchStatus 
	      AND BatchClosedatetime_Sort = max_BatchClosedatetime_Sort
	ORDER BY TerminalName , ClubID, Region, BatchNumber

DROP TABLE #tmpList
DROP TABLE #Clubs
DROP TABLE #TerminalNames
DROP TABLE #PlanRate
DROP TABLE #ToUSDPlanRate
DROP TABLE #Results

END

