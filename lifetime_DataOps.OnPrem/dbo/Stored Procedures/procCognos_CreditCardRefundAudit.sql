
CREATE PROC [dbo].[procCognos_CreditCardRefundAudit] (
    @TransactionStartDate  DATETIME,
    @TransactionEndDate DATETIME,
    @MMSRegionList VARCHAR(8000),
    @MMSClubIDList VARCHAR(8000)
)

AS
BEGIN 
SET XACT_ABORT ON
SET NOCOUNT ON



DECLARE @AdjustedTransactionEndDate DateTime
SET @AdjustedTransactionEndDate = DateAdd(Day,1,@TransactionEndDate)


SELECT DISTINCT Club.ClubID as ClubID
  INTO #Clubs
  FROM vClub Club
  JOIN fnParsePipeList(@MMSClubIDList) MMSClubIDList
    ON Convert(Varchar,Club.ClubID) = MMSClubIDList.Item
    OR @MMSClubIDList like '%All Clubs%'
  JOIN vValRegion Region
    On Club.ValRegionID = Region.ValRegionID
  JOIN fnParsePipeList(@MMSRegionList) RegionList
    ON Region.Description = RegionList.Item
    OR @MMSRegionList like '%All Regions%'

SELECT C.ClubId,
	   C.ClubName,
       CCTERM.Description as TerminalLocation,
       M.MemberID,
       M.Firstname + ' ' + M.Lastname as MemberName,
       P.Description as MembershipType,
       E.EmployeeID,
       E.Firstname + ' ' + E.Lastname as EmployeeName,
       CCTRAN.TranAmount,
	   CCTRAN.EmployeeID as CreditCardTran_EmployeeID,
	   CCTRAN.TransactionDateTime,
	   CCTRAN.CardType,
	   CCTRAN.MaskedAccountNumber,
	   CCTRAN.MaskedAccountNumber64,
	   CCTRAN.PaymentID,
	   CCTRAN.CardHolderName,
	   GETDATE() as ReportRunDateTime,	
	   Replace(Substring(convert(varchar,@TransactionStartDate,100),1,6)+', '+Substring(convert(varchar,@TransactionStartDate,100),8,4),'  ',' ')
                       + ' through ' + 
                       Replace(Substring(convert(varchar,@TransactionEndDate,100),1,6)+', '+Substring(convert(varchar,@TransactionEndDate,100),8,4),'  ',' ')as HeaderTransactionDateRange	

FROM vPTCreditcardTransaction CCTRAN
JOIN vptcreditcardbatch CCBATCH 
  ON CCTRAN.PTCreditCardBatchID = CCBATCH.PTCreditCardBatchID
JOIN vPTCreditCardTerminal CCTERM 
  ON CCBATCH.PTCreditCardTerminalID = CCTERM.PTCreditCardTerminalID
JOIN vClub C 
  ON C.ClubID = CCTERM.ClubID
JOIN #Clubs #C
  ON C.ClubID = #C.ClubID
LEFT JOIN vmember M 
  ON CCTRAN.MemberID = M.MemberID
LEFT JOIN vMembership MS 
  ON M.MembershipID = MS.MembershipID
LEFT JOIN vMembershipType MT 
  ON MS.MembershipTypeID = MT.MembershipTypeID
LEFT JOIN vProduct P 
  ON P.ProductID = MT.ProductID
LEFT JOIN vEmployee E 
  ON CCTRAN.EmployeeID = E.EmployeeID
WHERE CCTRAN.TransactionDateTime >= @TransactionStartDate
AND CCTRAN.TransactionDateTime < @AdjustedTransactionEndDate
AND CCTRAN.TransactionCode = 6
AND ISNULL(CCTRAN.VoidedFlag, 0) <> 1



Drop Table #Clubs

End
