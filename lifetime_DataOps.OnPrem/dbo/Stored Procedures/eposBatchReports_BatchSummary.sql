

-------------------------------------------- dbo.eposBatchReports_BatchSummary

CREATE PROC dbo.eposBatchReports_BatchSummary (
  @ClubID INT,
  @CloseStartDate SMALLDATETIME,
  @CloseEndDate SMALLDATETIME,
  @ClubName Varchar(75)
  )
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

SELECT CCTerm.Name AS TerminalName, CCTerm.ClubID,CCTerm.TerminalNumber,
       CCB.BatchNumber,CCBS.Description AS BatchStatusDescription,CCB.OpenDateTime AS
       BatchOpendatetime,CCB.CloseDateTime AS BatchClosedatetime,CCTran.CardOnFileFlag,
       CCTran.VoidedFlag, CCType.Description AS CardTypeDescription, CCTran.TranAmount,
       CCTran.EmployeeID, CCTran.MemberID,CCTran.TransactionDateTime,CCTran.AuthorizationCode,
       CCTran.PTCreditCardTransactionID, Right(CCTran.MaskedAccountNumber,4)AS CardAccountLast4Digits,
       CCTran.TransactionCode,@ClubName AS ClubName,CCB.SubmitDateTime,
       CCTran.TranSequenceNumber, CCB.ValCreditCardBatchStatusID
  FROM dbo.vPTCreditCardTransaction CCTran
  JOIN dbo.vPTCreditCardBatch CCB
       ON CCB.PTCreditCardBatchID = CCTran.PTCreditCardBatchID
  JOIN dbo.vPTCreditCardTerminal CCTerm
       ON CCB.PTCreditCardTerminalID = CCTerm.PTCreditCardTerminalID
  JOIN dbo.vValPTCreditCardType CCType
       ON CCTran.CardType = CCType.CardType
  JOIN dbo.vValCreditCardBatchStatus  CCBS
       ON CCB.ValCreditCardBatchStatusID = CCBS.ValCreditCardBatchStatusID
 WHERE CCTerm.ClubID = @ClubID AND
       CCB.CloseDateTime BETWEEN @CloseStartDate AND @CloseEndDate

-- Report Logging
UPDATE HyperionReportLog
SET EndDateTime = getdate()
WHERE ReportLogID = @Identity

END


