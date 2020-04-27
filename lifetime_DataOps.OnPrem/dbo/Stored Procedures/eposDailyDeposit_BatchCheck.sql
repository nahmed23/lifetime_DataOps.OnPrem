

-------------------------------------------- dbo.eposDailyDeposit_BatchCheck
--
-- Returns batch submitted dates for batches submitted within a selected date range
--     For club terminals which did not have a batch submitted in the 
--     selected range, this returns the date of the previous batch submitted
--
-- Parameters: A start date and end date for batch submitted dates 
--

CREATE PROC dbo.eposDailyDeposit_BatchCheck (
  @SubmitStartDate SMALLDATETIME,
  @SubmitEndDate SMALLDATETIME,
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

SELECT T.ClubID, T.TerminalNumber, 
       CASE WHEN B.SubmitDateTime < @SubmitStartDate THEN NULL
           ELSE B.BatchNumber END BatchNumber,
       CASE WHEN B.SubmitDateTime >= @SubmitStartDate THEN B.SubmitDateTime 
           ELSE NULL END SubmitDateTime,
       CASE WHEN B.SubmitDateTime < @SubmitStartDate THEN B.SubmitDateTime 
           ELSE NULL END SubmitDateTime2,
       T.Name AS TerminalName,B.CloseDateTime
  FROM dbo.vPTCreditCardTerminal T
   JOIN dbo.vPTCreditCardBatch B 
       ON T.PTCreditCardTerminalID = B.PTCreditCardTerminalID AND
       B.SubmitDateTime = (
           SELECT MAX(B2.SubmitDateTime)
             FROM dbo.vPTCreditCardBatch B2
            WHERE B2.PTCreditCardTerminalID = B.PTCreditCardTerminalID
                  AND T.Name IN(SELECT Location FROM #Locations ) ---= @Location
--                  AND T.Name = 'FrontDeskPOS'
                  AND B2.SubmitDateTime <= @SubmitEndDate 
                  AND DATEDIFF(Month,B2.UTCSubmitDateTime,GETDATE()) < 3
       )
 GROUP BY T.ClubID,T.TerminalNumber , B.BatchNumber,B.SubmitDateTime,T.Name,B.CloseDateTime
 ORDER BY T.ClubID,T.TerminalNumber , B.BatchNumber
 

  DROP TABLE #Locations
  DROP TABLE #tmpList

-- Report Logging
UPDATE HyperionReportLog
SET EndDateTime = getdate()
WHERE ReportLogID = @Identity

END

