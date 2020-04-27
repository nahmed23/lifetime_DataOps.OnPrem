

------------------------------------------ dbo.eposBatchReports_DroppedTickets
--
-- Returns ticket information for dropped tickets within a selected date range.
--
-- Parameters: A start date and end date for batch submitted dates 
--

CREATE PROC dbo.eposBatchReports_DroppedTickets (
  @StartDate SMALLDATETIME,
  @EndDate SMALLDATETIME
  )
AS

BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

select ccl.ClubID,
       ccl.Name as Location,
       CASE
	   WHEN cct.CardonFileFlag = 1
           THEN 'Yes'
	   ELSE 'No'
	END as CardOnFile,
       cct.CardType,
       cct.TransactionDateTime,
       cct.TranAmount,
       CASE cct.EntryDataSource
            WHEN 2 THEN 'Manual'
            WHEN 3 THEN 'Swiped'
	    WHEN 4 THEN 'Swiped'
            ELSE 'unknown'
       END			as EntryType,
       cct.AuthorizationCode,
       cct.AuthorizationResponseMessage
from dbo.VPTCreditCardTransaction cct
join dbo.VPTCreditCardBatch ccb
on cct.PTCreditCardBatchID = ccb.PTCreditCardBatchID
join dbo.VPTCreditCardTerminal ccl
on ccb.PTCreditCardTerminalID = ccl.PTCreditCardTerminalID
where cct.TransactionCode in (3,4)
and   cct.VoidedFlag = 0
and   cct.TranSequenceNumber is null
and   ccb.valCreditCardBatchStatusID = 3
and   ccb.SubmitDateTime >= @StartDate
and   ccb.SubmitDateTime <  @EndDate
order by ClubID, Location, TransactionDateTime

-- Report Logging
UPDATE HyperionReportLog
SET EndDateTime = getdate()
WHERE ReportLogID = @Identity

END

