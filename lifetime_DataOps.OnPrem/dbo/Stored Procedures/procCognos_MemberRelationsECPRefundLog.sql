
CREATE PROC [dbo].[procCognos_MemberRelationsECPRefundLog] (

@DrawerCloseBeginDate Datetime,
@DrawerCloseBeginTime Varchar(25),
@DrawerCloseEndDate   Datetime,
@DrawerCloseEndTime   Varchar(25),
@PaymentStatusIDList  Varchar(1000),
@RefundLogSortOrder   Varchar(50)


)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON


DECLARE @DrawerCloseStart DATETIME 
DECLARE @DrawerCloseEnd   DATETIME
DECLARE @HeaderDateStart  Varchar(110)
DECLARE @HeaderDateEnd    Varchar(110)

SET @DrawerCloseStart = DATEADD(mi,datediff(mi,0,convert(datetime,convert(varchar,@DrawerCloseBeginTime,108),108)),CONVERT(DATETIME,@DrawerCloseBeginDate,101))
SET @DrawerCloseEnd = DATEADD(mi,datediff(mi,0,convert(datetime,convert(varchar,@DrawerCloseEndTime,108),108)),CONVERT(DATETIME,@DrawerCloseEndDate,101))
SET @HeaderDateStart = Replace(SubString(Convert(Varchar,@DrawerCloseStart),1,3)+' '+LTRIM(SubString(Convert(Varchar,@DrawerCloseStart),5,DataLength(Convert(Varchar,@DrawerCloseStart))-12)),' '+Convert(Varchar,Year(@DrawerCloseStart)),', '+Convert(Varchar,Year(@DrawerCloseStart))) + ' ' + LTRIM(SubString(Convert(Varchar,@DrawerCloseStart,22),10,5) + ' ' + Right(ConverT(Varchar,@DrawerCloseStart,22),2))
SET @HeaderDateEnd = Replace(SubString(Convert(Varchar,@DrawerCloseEnd),1,3)+' '+LTRIM(SubString(Convert(Varchar,@DrawerCloseEnd),5,DataLength(Convert(Varchar,@DrawerCloseEnd))-12)),' '+Convert(Varchar,Year(@DrawerCloseEnd)),', '+Convert(Varchar,Year(@DrawerCloseEnd))) + ' ' + LTRIM(SubString(Convert(Varchar,@DrawerCloseEnd,22),10,5) + ' ' + Right(ConverT(Varchar,@DrawerCloseEnd,22),2))


CREATE TABLE #tmpList (StringField VARCHAR(50))

-- Parse the Status values into a temp table

EXEC procParseIntegerList @PaymentStatusIDList

-- Populating #StatusList

CREATE TABLE #StatusList (StatusID VARCHAR(50))
INSERT INTO #StatusList  (StatusID) SELECT StringField FROM #tmpList
TRUNCATE TABLE #tmpList


-- Populating #RefundTranIDs
CREATE TABLE #RefundTranIDs (MMSTranID INT)
INSERT INTO #RefundTranIds (MMSTranID)
SELECT DISTINCT MMSTran.MMSTranID
  FROM vMMSTranRefund MMSTranRefund
  JOIN vMMSTran MMSTran
    ON MMSTranRefund.MMSTranID = MMSTran.MMSTranID
  JOIN vDrawerActivity DrawerActivity
    ON DrawerActivity.DrawerActivityID = MMSTran.DrawerActivityID
  JOIN vPayment Payment
    ON MMSTran.MMSTranID = Payment.MMSTranID
  JOIN vPaymentRefund PaymentRefund
    ON PaymentRefund.PaymentID = Payment.PaymentID
 WHERE MMSTran.TranVoidedID IS NULL
   AND DrawerActivity.CloseDateTime >= @DrawerCloseStart
   AND DrawerActivity.CloseDateTime <= @DrawerCloseEnd
   AND Payment.ValPaymentTypeID in (9,10,13)
   AND PaymentRefund.ValPaymentStatusID In (SELECT StatusID FROM #StatusList)

-- Populating #RefundCheckDates
CREATE TABLE #RefundCheckDates (MMSTranID INT, LastCheckDate DATETIME)
INSERT INTO #RefundCheckDates (MMSTranID, LastCheckDate)
SELECT MMSTran.MMSTranID, MAX(PostDateTime) 
  FROM vMMSTranRefund MMSTranRefund
  JOIN #RefundTranIDs
    ON MMSTranRefund.MMSTranID = #RefundTranIDs.MMSTranID
  JOIN vMMSTranRefundMMSTran MMSTranRefundMMSTran
    ON MMSTranRefund.MMSTranRefundID = MMSTranRefundMMSTran.MMSTranRefundID
  JOIN vMMSTran MMSTran
    ON MMSTranRefundMMSTran.OriginalMMSTranID = MMSTran.MMSTranID
  JOIN vPayment Payment
    ON Payment.MMSTranID = MMSTran.MMSTranID
 WHERE MMSTran.TranVoidedID IS NULL
   AND Payment.ValPaymentTypeID = 2
 GROUP BY MMSTran.MMSTranID


-- Populating #RefundAccountCodes
CREATE TABLE #RefundAccountCodes (MMSTranID INT, AccountCode VARCHAR(50))
INSERT INTO #RefundAccountCodes
SELECT #RefundTranIDs.MMSTranID,
       '1205-' 
       + CAST(CASE WHEN MMSTran.ReasonCodeID = 108 THEN (SELECT Club.GLClubID
                                                           FROM vMembership Membership
                                                           JOIN vClub Club
                                                             ON Membership.ClubID = Club.ClubID
                                                          WHERE Membership.MembershipID = MMSTran.MembershipID)
                   ELSE (SELECT Club.GLClubID
                           FROM vMMSTranRefund MMSTranRefund
                           JOIN vMMSTranRefundMMSTran MMSTranRefundMMSTran
                             ON MMSTranRefundMMSTran.MMSTranRefundID = MMSTranRefund.MMSTranRefundID
                           JOIN vMMSTran SubMMSTran
                             ON MMSTranRefundMMSTran.OriginalMMSTranID = SubMMSTran.MMSTranID
                           JOIN vMembership Membership
                             ON SubMMSTran.MembershipID = Membership.MembershipID
                           JOIN vClub Club
                             ON Club.ClubID = SubMMSTran.ClubID 
                          WHERE MMSTranRefund.MMSTranID = #RefundTranIDs.MMSTranID)
               END AS VARCHAR(5)) AccountCode
  FROM #RefundTranIds #RefundTranIDs
  JOIN vMMSTran MMSTran
    ON #RefundTranIDs.MMSTranID = MMSTran.MMSTranID

SELECT Club.ClubName RequestingClub,
       Replace(Substring(convert(varchar, MMSTran.PostDateTime,100),1,6)+', '+Substring(convert(varchar, MMSTran.PostDateTime,100),8,10)+' '+Substring(convert(varchar,MMSTran.PostDateTime,100),18,2),'  ',' ') RequestDate,
       MMSTran.MemberID,
       MMSTran.MMSTranID RefundTranID,
       CASE WHEN #RefundCheckDates.LastCheckDate is Null THEN ''
            ELSE Replace(Substring(convert(varchar, #RefundCheckDates.LastCheckDate,100),1,6)+', '+Substring(convert(varchar, #RefundCheckDates.LastCheckDate,100),8,10)+' '+Substring(convert(varchar,#RefundCheckDates.LastCheckDate,100),18,2),'  ',' ')
        END LastCheckDate,
       PaymentAccount.RoutingNumber,
       ValCurrencyCode.CurrencyCode LocalCurrencyCode,
       ABS(Payment.PaymentAmount) LocalECPAmount,
       #RefundAccountCodes.AccountCode,
       PaymentAccount.Name AccountName,
       ValPaymentType.Description AccountType,
       ValPaymentStatus.Description RequestStatus,
       Replace(Substring(convert(varchar, PaymentRefund.PaymentIssuedDateTime,100),1,6)+', '+Substring(convert(varchar, PaymentRefund.PaymentIssuedDateTime,100),8,10)+' '+Substring(convert(varchar,PaymentRefund.PaymentIssuedDateTime,100),18,2),'  ',' ') IssueDate,
       @RefundLogSortOrder RefundLogSortOrderHeader,
       @HeaderDateStart DrawerCloseStartDateTime,
       @HeaderDateEnd  DrawerCloseEndDateTime,
       Replace(@PaymentStatusIDList,'|',', ') SelectedPaymentStatus,
       CASE WHEN @RefundLogSortOrder = 'By Club and Payee Name' THEN Club.ClubName + '-' + PaymentAccount.Name
            ELSE Convert(Varchar,MMSTran.PostDateTime,121) 
        END ReportSortingValue
  FROM vMMSTranRefund MMSTranRefund
  JOIN #RefundTranIds
    ON MMSTranRefund.MMSTranID = #RefundTranIDs.MMSTranID
  JOIN vMMSTran MMSTran 
    ON MMSTranRefund.MMSTranID = MMSTran.MMSTranID
  JOIN vClub Club
    ON Club.ClubID = MMSTranRefund.RequestingClubID
  JOIN vValCurrencyCode ValCurrencyCode
    ON ISNULL(MMSTran.ValCurrencyCodeID,1)  = ValCurrencyCode.ValCurrencyCodeID
  JOIN vPayment Payment
    ON Payment.MMSTranID = MMSTran.MMSTranID
  JOIN vPaymentRefund PaymentRefund
    ON PaymentRefund.PaymentID = Payment.PaymentID
  JOIN vPaymentAccount PaymentAccount
    ON PaymentAccount.PaymentID = Payment.PaymentID
  JOIN #RefundAccountCodes 
    ON #RefundAccountCodes.MMSTranID = MMSTran.MMSTranID
  JOIN vValPaymentType ValPaymentType
    ON ValPaymentType.ValPaymentTypeID = Payment.ValPaymentTypeID
  JOIN vValPaymentStatus ValPaymentStatus
    ON ValPaymentStatus.ValPaymentStatusID = PaymentRefund.ValPaymentStatusID
  LEFT JOIN #RefundCheckDates 
    ON #RefundCheckDates.MMSTranID = #RefundTranIds.MMSTranID
 WHERE Payment.ValPaymentTypeID IN ( 9, 10, 13 )
   AND PaymentRefund.ValPaymentStatusID In (Select StatusID From #StatusList)
 ORDER BY RefundTranID,LocalECPAmount

-- Droping a Temp tables
 
DROP TABLE  #tmpList
DROP TABLE  #StatusList
DROP TABLE  #RefundTranIDs
DROP TABLE  #RefundCheckDates
DROP TABLE  #RefundAccountCodes
--DROP TABLE  #MMSTran


END

