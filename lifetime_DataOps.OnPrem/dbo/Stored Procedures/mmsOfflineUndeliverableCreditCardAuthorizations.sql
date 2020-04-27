
-- =============================================
-- Object:			dbo.[mmsOfflineUndeliverableCreditCardAuthorizations]
-- Author:			Ruslan Condratiuc
-- Create date: 	October 2008
-- Description:		Returns Offline Undeliverable Credit Card Authorizations for the Café Department AND Spa (if there are any).  
-- Parameters:		a list of credit card terminal ids; transactions start and transactions end date
-- Modified date:	
-- Release date:	date / dbcr
-- Exec mmsOfflineUndeliverableCreditCardAuthorizations '170|91|149|170|91|82|57|30|97|', '09/01/08', '09/30/08'
-- =============================================


CREATE  PROC [dbo].[mmsOfflineUndeliverableCreditCardAuthorizations] (
	@PTCreditCardTerminalID varchar(2000),
	@StartDate DateTime,  	
	@EndDate DateTime
)
AS
BEGIN

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

CREATE TABLE #tmpList (StringField INT)
CREATE TABLE #CCTerminals (PTCreditCardTerminalID INT)

BEGIN
   EXEC procParseIntegerList @PTCreditCardTerminalID
   INSERT INTO #CCTerminals (PTCreditCardTerminalID) SELECT StringField FROM #tmpList
   TRUNCATE TABLE #tmpList
END


SELECT
R.Description AS Region, 
C.ClubName AS ClubName, 
VCCTL.Description AS TerminalName, 
CCUT.CardType AS CardType,
CCUT.MaskedAccountNumber64 AS AccountNumber, 
CCUT.ReasonMessage AS FailureReason, 
CCUT.TransactionDateTime AS TransactionDateTime, 
CCUT.MemberID AS CardHolderMemberID, 
CCUT.CardHolderName AS CardHolderName, 
CCUT.CardHolderStreetAddress AS CardHolderAddress,  
CCUT.CardHolderZipCode AS CardHolderZipCode,
CCUT.TranAmount AS DollarAmount, 
CCT.TerminalNumber AS MerchantName,
CCT.MerchantNumber AS MerchantNumber,
VCCTL.Description AS ClubLocation,
CCUT.ExpirationDate AS ExpirationDate, 
case when CCUT.EntryDataSource = 2 then 'Manual' else 'Swiped' END AS EntryType,
CCUT.EmployeeID,
CCUT.PTCreditCardTerminalID 

FROM vPTCreditCardUndeliverableTransaction CCUT
INNER JOIN vPTCreditCardTerminal CCT 
	ON CCT.ValCreditCardTerminalLocationID = CCUT.PTCreditCardTerminalID
INNER JOIN vValCreditCardTerminalLocation VCCTL
	ON VCCTL.ValCreditCardTerminalLocationid = CCT.ValCreditCardTerminalLocationID 
INNER JOIN vClub C 
	ON C.ClubID = CCT.ClubID
INNER JOIN vValRegion R 
	ON C.ValRegionID=R.ValRegionID
INNER JOIN vValPTCreditCardEntryDataSource CCEDS
	ON ValPTCreditCardEntryDataSourceID = CCUT.EntryDataSource
INNER JOIN #CCTerminals tCCT
	ON tCCT.PTCreditCardTerminalID=CCUT.PTCreditCardTerminalID

WHERE  
	CCUT.TransactionDateTime BETWEEN  @StartDate AND @EndDate


DROP TABLE #tmpList 
DROP TABLE #CCTerminals 
	
-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END

