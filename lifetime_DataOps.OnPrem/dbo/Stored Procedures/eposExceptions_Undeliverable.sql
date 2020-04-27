

--------------------------------------------- dbo.eposExceptions_Undeliverable
--
-- Returns undeliverable PaymenTech credit card transactions for a selected 
-- club and date range.
--

CREATE PROCEDURE dbo.eposExceptions_Undeliverable(
          @ClubID INT,
          @StartDate DATETIME,
          @EndDate DATETIME
)

AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

  SELECT T.Clubid,T.Terminalnumber,T.Name AS TerminalName, UT.Transactiondatetime,
         UT.Memberid, UT.Tranamount, Right(UT.Accountnumber,4) AS AccountnumberLast4, 
         CT.Description AS CardTypeDescription,UT.Cardonfileflag, UT.Reasonmessage, 
         UT.Referencecode,UT.Ptcreditcardterminalid,UT.PTCreditCardUndeliverableTransactionID
   FROM dbo.vPTCreditCardUndeliverableTransaction UT
    JOIN dbo.vPTCreditCardTerminal T
         ON UT.Ptcreditcardterminalid = T.Ptcreditcardterminalid
    JOIN dbo.vValPTCreditCardType CT
         ON UT.Cardtype = CT.Cardtype
   WHERE UT.Transactiondatetime >= @StartDate AND
         UT.Transactiondatetime <= @EndDate AND
         T.Clubid = @ClubID

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END

