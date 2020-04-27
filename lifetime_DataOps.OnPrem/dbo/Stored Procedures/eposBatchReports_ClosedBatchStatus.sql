

--------------------------------------- dbo.eposBatchReports_ClosedBatchStatus
--
-- Returns batch information for batches closed within a selected date range.
--
-- Parameters: A club list and a start date and end date for batch closed dates 
--
-- EXEC dbo.eposBatchReports_ClosedBatchStatus '14|15|50|51|52|53|128|150', '9/1/05', '11/23/05', 'FrontDeskPOS|InterimSpaPOS'
--
CREATE PROC dbo.eposBatchReports_ClosedBatchStatus (
  @ClubList VARCHAR(1000),
  @CloseStartDate SMALLDATETIME,
  @CloseEndDate SMALLDATETIME,
  @TerminalNameList VARCHAR(50)
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
--   INSERT INTO #Clubs EXEC procParseStringList @clubList
   EXEC procParseStringList @ClubList
--   EXEC procParseIntegerList @ClubList
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

SELECT CCTerm.Name AS TerminalName, CCTerm.ClubID, CCB.BatchNumber, CCB.OpenDateTime AS
       BatchOpendatetime, CCB.CloseDateTime AS BatchClosedatetime, CCTran.VoidedFlag, 
       CCTran.TransactionCode, CCTran.Voidedflag, CCTran.TranAmount, CCB.SubmitDateTime
  FROM dbo.vPTCreditCardTransaction CCTran
  JOIN dbo.vPTCreditCardBatch CCB
       ON CCB.PTCreditCardBatchID = CCTran.PTCreditCardBatchID
  JOIN dbo.vPTCreditCardTerminal CCTerm
       ON CCB.PTCreditCardTerminalID = CCTerm.PTCreditCardTerminalID
  JOIN dbo.vValPTCreditCardType CCType
       ON CCTran.CardType = CCType.CardType
  JOIN dbo.vValCreditCardBatchStatus  CCBS
       ON CCB.ValCreditCardBatchStatusID = CCBS.ValCreditCardBatchStatusID
  JOIN #Clubs CS
       ON CCTerm.ClubID = CS.ClubID OR CS.ClubID = 0 -- All
  JOIN #TerminalNames TN
       ON CCTerm.Name = TN.TerminalName
 WHERE (CCB.CloseDateTime BETWEEN @CloseStartDate AND @CloseEndDate) --AND
--	CCTerm.Name = @TerminalName

-- Report Logging
UPDATE HyperionReportLog
SET EndDateTime = getdate()
WHERE ReportLogID = @Identity

END

