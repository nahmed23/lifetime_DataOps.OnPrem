



-- EXEC mmsBatchReports_BatchSummary '141', 'Apr 1, 2011', 'Apr 11, 2011'

CREATE    PROC [dbo].[mmsBatchReports_BatchSummary] (
  @ClubID INT,
  @CloseStartDate SMALLDATETIME,
  @CloseEndDate SMALLDATETIME
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
   
   EXEC procParseStringList @ClubID
   INSERT INTO #Clubs (ClubID) SELECT StringField FROM #tmpList
   TRUNCATE TABLE #tmpList

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

CREATE TABLE #ReportUnion (TerminalName Varchar(50), ClubID INT, TerminalNumber INT, BatchNumber SmallINT, BatchStatusDescription Varchar(50),
                          BatchOpenDateTime DateTime, BatchCloseDatetime DateTime, CardOnFileFlag Bit, VoidedFlag Bit, 
                          CardTypeDescription Varchar(50), TranAmount Numeric(10,3), EmployeeID Int, MemberID Int, TransactionDateTime DateTime, 
                          AuthorizationCode Varchar(50), PTCreditCardTransactionID Int, CardLast4Digits Varchar(50), TransactionCode SmallInt, 
                          ClubName Varchar(50), SubmitDateTime DateTime, TranSequenceNumber SmallInt, ValCreditCardBatchStatusID SmallInt,
                          TipAmount Numeric(10,3), PTStoredValueCardTransactionID Int,MerchantNumber BigInt, BatchID Int, DrawerActivityID Int,
                          DrawerCloseEmployeeFirstName Varchar(50), DrawerCloseEmployeeLastName Varchar(50), ResponseApprovedAmount Numeric(10,3))

INSERT INTO #ReportUnion(TerminalName, ClubID, TerminalNumber, BatchNumber, BatchStatusDescription,
                          BatchOpenDateTime, BatchCloseDatetime, CardOnFileFlag, VoidedFlag, 
                          CardTypeDescription, TranAmount, EmployeeID, MemberID, TransactionDateTime, 
                          AuthorizationCode, PTCreditCardTransactionID, CardLast4Digits, TransactionCode, 
                          ClubName, SubmitDateTime, TranSequenceNumber, ValCreditCardBatchStatusID,
                          TipAmount, PTStoredValueCardTransactionID,MerchantNumber, BatchID, DrawerActivityID,
                          DrawerCloseEmployeeFirstName, DrawerCloseEmployeeLastName,ResponseApprovedAmount )

-----To return all Credit Card related transactons

SELECT CCTerm.Name, CCTerm.ClubID,CCTerm.TerminalNumber,CCB.BatchNumber,CCBS.Description,
       CCB.OpenDateTime, CCB.CloseDateTime,CCTran.CardOnFileFlag,CCTran.VoidedFlag, 
       CCType.Description, CCTran.TranAmount,CCTran.EmployeeID, CCTran.MemberID,CCTran.TransactionDateTime,
       CCTran.AuthorizationCode,CCTran.PTCreditCardTransactionID, Right(CCTran.MaskedAccountNumber,4),CCTran.TransactionCode, 
       C.ClubName,CCB.SubmitDateTime,CCTran.TranSequenceNumber, CCB.ValCreditCardBatchStatusID, 
       CCTran.TipAmount, Null,CCTerm.MerchantNumber, CCB.PTCreditCardBatchID, CCB.DrawerActivityID,
       E.FirstName,E.LastName, Null
  FROM vPTCreditCardTransaction CCTran
  JOIN vPTCreditCardBatch CCB
       ON CCB.PTCreditCardBatchID = CCTran.PTCreditCardBatchID
  JOIN vPTCreditCardTerminal CCTerm
       ON CCB.PTCreditCardTerminalID = CCTerm.PTCreditCardTerminalID
  JOIN vValPTCreditCardType CCType
       ON CCTran.CardType = CCType.CardType
  JOIN vValCreditCardBatchStatus  CCBS
       ON CCB.ValCreditCardBatchStatusID = CCBS.ValCreditCardBatchStatusID
  JOIN vClub C
       ON CCTerm.ClubID = C.ClubID
  LEFT JOIN vDrawerActivity DA
       ON CCB.DrawerActivityID = DA.DrawerActivityID
  LEFT JOIN vEmployee E
       ON DA.CloseEmployeeID = E.EmployeeID
  
 WHERE CCTerm.ClubID = @ClubID AND
       CCB.CloseDateTime BETWEEN @CloseStartDate AND @CloseEndDate

UNION

-----To return all Gift Card related transactons

SELECT CCTerm.Name, CCTerm.ClubID,CCTerm.TerminalNumber,CCB.BatchNumber,CCBS.Description,
       CCB.OpenDateTime,CCB.CloseDateTime,Null,SVCTran.VoidedFlag, 
       'Gift Card', SVCTran.TranAmount,SVCTran.EmployeeID, Null ,SVCTran.TransactionDateTime,
       SVCTran.ResponseAuthorizationCode,Null,Right(SVCTran.MaskedAccountNumber,4),SVCTran.TransactionCode, 
       C.ClubName,CCB.SubmitDateTime,SVCTran.TranSequenceNumber, CCB.ValCreditCardBatchStatusID, 
       SVCTran.CounterTipAmount, SVCTran.PTStoredValueCardTransactionID,CCTerm.MerchantNumber, CCB.PTCreditCardBatchID,
       CCB.DrawerActivityID, E.FirstName,E.LastName, SVCTran.ResponseApprovedAmount
  FROM vPTStoredValueCardTransaction SVCTran
  JOIN vPTCreditCardBatch CCB
       ON CCB.PTCreditCardBatchID = SVCTran.PTCreditCardBatchID
  JOIN vPTCreditCardTerminal CCTerm
       ON CCB.PTCreditCardTerminalID = CCTerm.PTCreditCardTerminalID
  Join vClub C
       ON C.ClubID = CCTerm.ClubID
  JOIN vValCreditCardBatchStatus  CCBS
       ON CCB.ValCreditCardBatchStatusID = CCBS.ValCreditCardBatchStatusID
  LEFT JOIN vDrawerActivity DA
       ON CCB.DrawerActivityID = DA.DrawerActivityID
  LEFT JOIN vEmployee E
       ON DA.CloseEmployeeID = E.EmployeeID
 WHERE CCTerm.ClubID = @ClubID AND
       CCB.CloseDateTime BETWEEN @CloseStartDate AND @CloseEndDate


Select TerminalName, #ReportUnion.ClubID, TerminalNumber, BatchNumber, BatchStatusDescription,      
	   Replace(SubString(Convert(Varchar, BatchOpenDateTime),1,3)+' '+LTRIM(SubString(Convert(Varchar, BatchOpenDateTime),5,DataLength(Convert(Varchar, BatchOpenDateTime))-12)),' '+Convert(Varchar,Year(BatchOpenDateTime)),', '+Convert(Varchar,Year(BatchOpenDateTime))) + ' ' + LTRIM(SubString(Convert(Varchar, BatchOpenDateTime,22),10,5) + ' ' + Right(Convert(Varchar, BatchOpenDateTime ,22),2)) as BatchOpenDateTime,           
	   Replace(SubString(Convert(Varchar, BatchCloseDateTime),1,3)+' '+LTRIM(SubString(Convert(Varchar, BatchCloseDateTime),5,DataLength(Convert(Varchar, BatchCloseDateTime))-12)),' '+Convert(Varchar,Year(BatchCloseDateTime)),', '+Convert(Varchar,Year(BatchCloseDateTime))) + ' ' + LTRIM(SubString(Convert(Varchar, BatchCloseDateTime,22),10,5) + ' ' + Right(Convert(Varchar, BatchCloseDateTime ,22),2)) as BatchCloseDatetime,    
	   CardOnFileFlag, VoidedFlag, 
       CardTypeDescription, EmployeeID, MemberID, TransactionDateTime, 
       AuthorizationCode, PTCreditCardTransactionID, CardLast4Digits, TransactionCode, 
       #ReportUnion.ClubName, 
	   Replace(SubString(Convert(Varchar, SubmitDateTime),1,3)+' '+LTRIM(SubString(Convert(Varchar, SubmitDateTime),5,DataLength(Convert(Varchar, SubmitDateTime))-12)),' '+Convert(Varchar,Year(SubmitDateTime)),', '+Convert(Varchar,Year(SubmitDateTime))) + ' ' + LTRIM(SubString(Convert(Varchar, SubmitDateTime,22),10,5) + ' ' + Right(Convert(Varchar, SubmitDateTime ,22),2)) as SubmitDateTime,    
	   TranSequenceNumber, ValCreditCardBatchStatusID,
       PTStoredValueCardTransactionID,MerchantNumber, BatchID, DrawerActivityID,
       DrawerCloseEmployeeFirstName, DrawerCloseEmployeeLastName, 
/******  Foreign Currency Stuff  *********/
	   VCC.CurrencyCode as LocalCurrencyCode,
       #PlanRate.PlanRate,
       @ReportingCurrencyCode as ReportingCurrencyCode,
	   TranAmount * #PlanRate.PlanRate as TranAmount,	   
	   TranAmount as LocalCurrency_TranAmount,	   
	   TranAmount * #ToUSDPlanRate.PlanRate as USD_TranAmount,
  	   TipAmount * #PlanRate.PlanRate as TipAmount,	   
	   TipAmount as LocalCurrency_TipAmount,	   
	   TipAmount * #ToUSDPlanRate.PlanRate as USD_TipAmount,
	   ResponseApprovedAmount * #PlanRate.PlanRate as ResponseApprovedAmount,	   
	   ResponseApprovedAmount as LocalCurrency_ResponseApprovedAmount,	   
	   ResponseApprovedAmount * #ToUSDPlanRate.PlanRate as USD_ResponseApprovedAmount
/***************************************/	   

    
From #ReportUnion 
/********** Foreign Currency Stuff **********/
  JOIN vClub C1
       ON #ReportUnion.ClubID = C1.ClubID
  JOIN vValCurrencyCode VCC
       ON C1.ValCurrencyCodeID = VCC.ValCurrencyCodeID
  JOIN #PlanRate
       ON VCC.CurrencyCode = #PlanRate.FromCurrencyCode      
  JOIN #ToUSDPlanRate
       ON VCC.CurrencyCode = #ToUSDPlanRate.FromCurrencyCode
/*******************************************/

DROP TABLE #ReportUnion
DROP TABLE #PlanRate
DROP TABLE #ToUSDPlanRate

-- Report Logging
UPDATE HyperionReportLog
SET EndDateTime = getdate()
WHERE ReportLogID = @Identity

END

