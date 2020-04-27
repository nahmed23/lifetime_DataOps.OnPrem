

-------------------------------------------- dbo.eposDailyDeposit_CardOnFile
----- Returns Card On File and Card Present transactions, summarized by date, for batches 
----- closed within a selected date range 
----- Parameters: Batch Close date range, terminal location

-- EXEC eposDailyDeposit_CardOnFile '10/17/05', '10/18/05', 'FrontDeskPOS'
-- EXEC eposDailyDeposit_CardOnFile '10/17/05', '10/18/05', 'Cafe/BistroPOS'
-- EXEC eposDailyDeposit_CardOnFile '10/17/05', '10/18/05', 'InterimSpaPOS'

CREATE PROC dbo.eposDailyDeposit_CardOnFile (
 @CloseStartDate SMALLDATETIME,
 @CloseEndDate  SMALLDATETIME,
 @Location VARCHAR(100)
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
  
  -- Parse the Locations into a temp table
  EXEC procParseStringList @Location
  CREATE TABLE #Locations (Location VARCHAR(50))
  INSERT INTO #Locations (Location) SELECT StringField FROM #tmpList


SELECT TRN.PTCreditCardBatchID, CONVERT(VARCHAR(10), B.CloseDateTime, 101) AS ClosedDate, 
 Sum(TRN.TranAmount) AS TranAmount, TRN.CardType, TRN.CardOnFileFlag, TERM.ClubID, TERM.TerminalNumber, 
 B.BatchNumber, CCBS.Description AS Status, TERM.Name AS TerminalName, B.SubmitDateTime

FROM dbo.vPTCreditCardBatch B 
  JOIN dbo.vPTCreditCardTransaction TRN
     ON B.PTCreditCardBatchID = TRN.PTCreditCardBatchID
  JOIN dbo.vPTCreditCardTerminal TERM
     ON TERM.PTCreditCardTerminalID = B.PTCreditCardTerminalID
  JOIN dbo.vValCreditCardBatchStatus CCBS 
     ON CCBS.ValCreditCardBatchStatusID = B.ValCreditCardBatchStatusID
  JOIN #Locations L
     ON TERM.Name = L.Location
WHERE  B.CloseDateTime >= @CloseStartDate AND
              B.CloseDateTime <= @CloseEndDate AND 
              TRN.VoidedFlag = 0 AND 
             (NOT (TRN.TransactionCode = 2) OR TRN.TransactionCode IS NULL) ----AND 
              ------TERM.Name = @Location --AND 
--              TERM.Name='FrontDeskPOS' AND 
--              TRN.CardOnFileFlag=1
GROUP BY TRN.PTCreditCardBatchID, CONVERT(VARCHAR(10), B.CloseDateTime, 101), 
 TRN.CardType, TRN.CardOnFileFlag, TERM.ClubID, TERM.TerminalNumber, 
 B.BatchNumber, CCBS.Description, TERM.Name, B.SubmitDateTime

  DROP TABLE #Locations
  DROP TABLE #tmpList

-- Report Logging
UPDATE HyperionReportLog
SET EndDateTime = getdate()
WHERE ReportLogID = @Identity

END

