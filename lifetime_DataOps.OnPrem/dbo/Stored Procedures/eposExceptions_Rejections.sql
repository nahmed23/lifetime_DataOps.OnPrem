

------------------------------------------------ dbo.eposExceptions_Rejections
--
-- Returns rejected PaymenTech credit card transactions for a selected 
-- club and date range.
--

CREATE PROCEDURE dbo.eposExceptions_Rejections(
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

  SELECT T.Clubid,T.Terminalnumber,T.Name AS TerminalName, RT.Transactiondatetime,
         RT.Memberid, RT.Tranamount, Right(RT.Accountnumber,4) AS AccountnumberLast4, CT.Description AS CardTypeDescription,
         RT.Cardonfileflag, RT.Errorcode, RT.Errormessage, RT.Ptcreditcardterminalid,
         RT.Referencecode,RT.PTCreditCardRejectedTransactionID
   FROM dbo.vPTCreditCardRejectedTransaction RT
    JOIN dbo.vPTCreditCardTerminal T
         ON RT.Ptcreditcardterminalid = T.Ptcreditcardterminalid
    JOIN dbo.vValPTCreditCardType CT
         ON RT.Cardtype = CT.Cardtype
   WHERE RT.Transactiondatetime >= @StartDate AND
         RT.Transactiondatetime <= @EndDate AND
         T.Clubid = @ClubID

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END

