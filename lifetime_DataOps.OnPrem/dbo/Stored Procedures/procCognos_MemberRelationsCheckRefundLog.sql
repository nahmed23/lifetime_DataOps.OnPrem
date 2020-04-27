
CREATE PROC [dbo].[procCognos_MemberRelationsCheckRefundLog] (

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


CREATE     TABLE #tmpList (StringField VARCHAR(50))

-- Parse the Status values into a temp table

EXEC procParseIntegerList @PaymentStatusIDList

CREATE TABLE #StatusList (StatusID VARCHAR(50))
INSERT INTO #StatusList  (StatusID) SELECT StringField FROM #tmpList
TRUNCATE TABLE #tmpList

SELECT MMSTran.MMSTranID, 
       MMSTran.ClubID,
       MMSTran.TranVoidedID,
       MMSTran.DrawerActivityID,
       MMSTran.ReasonCodeID,
       MMSTran.MembershipID,
       MMSTran.MemberID,
       MMSTran.PostDateTime,
       MMSTran.ValCurrencyCodeID,
       MMSTranRefund.RequestingClubID,
       MMSTranRefund.MMSTranRefundID
INTO #MMSTran
FROM vMMSTran MMSTran WITH (NOLOCK)
JOIN vMMSTranRefund MMSTranRefund
  ON MMSTran.MMSTranID = MMSTranRefund.MMSTranID

     
CREATE INDEX IX_MMSTranID ON #MMSTran(MMSTranID)
CREATE INDEX IX_DrawerActivityID ON #MMSTran(DrawerActivityID)
CREATE INDEX IX_ClubID ON #MMSTran(ClubID)

-- Populating #RefundTranIDs

CREATE TABLE #RefundTranIDs ( MMSTranID INT )
INSERT INTO #RefundTranIds ( MMSTranID )
    SELECT DISTINCT MMSTran.MMSTranID

    FROM #MMSTran AS MMSTran 
    --vMMSTranRefund AS MMSTranRefund (this is included in #MMSTran)
    JOIN vDrawerActivity AS DrawerActivity
        ON DrawerActivity.DrawerActivityID = MMSTran.DrawerActivityID
    JOIN vPayment AS Payment
        ON MMSTran.MMSTranID = Payment.MMSTranID
    JOIN vPaymentRefund AS PaymentRefund
        ON Payment.PaymentID = PaymentRefund.PaymentID

    WHERE MMSTran.TranVoidedID IS NULL
       AND  ( ( DrawerActivity.CloseDateTime >= @DrawerCloseStart
                AND
               DrawerActivity.CloseDateTime <= @DrawerCloseEnd  )
              OR
              ( DrawerActivity.CloseDateTime < @DrawerCloseStart
                AND
               PaymentRefund.StatusChangeDateTime >= @DrawerCloseStart
                AND
               PaymentRefund.StatusChangeDateTime <= @DrawerCloseEnd ) 
           )
       AND  Payment.ValPaymentTypeID = 2
       AND  PaymentRefund.ValPaymentStatusID IN ( SELECT StatusID FROM #StatusList )


-- Populating #RefundAccountCodes

CREATE TABLE #RefundAccountCodes (MMSTranID INT, AccountCode Varchar (50) )
INSERT INTO #RefundAccountCodes
    SELECT #RefundTranIDs.MMSTranID,
           '1205-' 
           + Cast(
              ( Case 
                    When MMSTran.ReasonCodeID = 108
                    Then ( SELECT Club.GLClubID
                               FROM vMembership AS Membership
                           JOIN vClub AS Club
                           ON Membership.ClubID = Club.ClubID

                           WHERE Membership.MembershipID = MMSTran.MembershipID)
                    ELSE ( SELECT Club.GLClubID 
                           FROM #MMSTran AS SubMMSTran
                           -- vMMSTranRefund MMSTranRefund -- included in #MMSTran population
                           JOIN vMMSTranRefundMMSTran AS MMSTranRefundMMSTran
                           ON SubMMSTran.MMSTranRefundID = MMSTranRefundMMSTran.MMSTranRefundID
                           --JOIN vMMSTran AS SubMMSTran -- included in #MMSTran population
                           AND SubMMSTran.MMSTranID = MMSTranRefundMMSTran.OriginalMMSTranID
                           JOIN vClub AS Club
                           ON Club.ClubID = SubMMSTran.ClubID
                           WHERE  SubMMSTran.MMSTranID = #RefundTranIDs.MMSTranID
                          )
                END ) 
            AS VARCHAR(5) ) AS AccountCode
    FROM #RefundTranIDs 
    JOIN #MMSTran AS MMSTran
      ON #RefundTranIDs.MMSTranID = MMSTran.MMSTranID

;

SELECT Club.ClubName        AS RequestingClub,
       
       Replace(SubString(Convert(Varchar,MMSTran.PostDateTime),1,3)+' '+LTRIM(SubString(Convert(Varchar, MMSTran.PostDateTime),5,DataLength(Convert(Varchar, MMSTran.PostDateTime))-12)),' '+Convert(Varchar,Year(MMSTran.PostDateTime)),', '+Convert(Varchar,Year(MMSTran.PostDateTime))) + ' ' + LTRIM(SubString(Convert(Varchar, MMSTran.PostDateTime,22),10,5) + ' ' + Right(ConverT(Varchar, MMSTran.PostDateTime,22),2)) RequestDate,

       CASE
          WHEN Member.LastName = 'House Account'
             THEN 'Nonmember'
                ELSE CAST( MMSTran.MemberID AS VARCHAR( 50 ) )
       END AS MemberID,

      MMSTran.MMSTranID AS RefundTranID,
      PaymentRefundContact.LastName + ', ' + PaymentRefundContact.FirstName AS PayeeName,
      PaymentRefundContact.AddressLine1 + 
      CASE WHEN PaymentRefundContact.AddressLine2 = '' 
               THEN '' 
                   ELSE ', ' + PaymentRefundContact.AddressLine2 
      END+ ', ' + PaymentRefundContact.City + ',' +ValState.Abbreviation + ', ' + PaymentRefundContact.Zip + 
      CASE WHEN PaymentRefundContact.ValCountryID <> 1 
               THEN ', ' + ValCountry.Abbreviation 
                   ELSE ''
      END AS MailingAddress,
ValCurrencyCode.CurrencyCode           AS LocalCurrencyCode,
Abs(Payment.PaymentAmount)             AS LocalCurrencyCheckAmount,
#RefundAccountCodes.AccountCode,
PaymentRefund.ReferenceNumber,
ValPaymentStatus.Description           AS RequestStatus,
Replace(SubString(Convert(Varchar,PaymentRefund.PaymentIssuedDateTime),1,3)+' '+LTRIM(SubString(Convert(Varchar,PaymentRefund.PaymentIssuedDateTime),5,DataLength(Convert(Varchar,PaymentRefund.PaymentIssuedDateTime))-12)),' '+Convert(Varchar,Year(PaymentRefund.PaymentIssuedDateTime)),', '+Convert(Varchar,Year(PaymentRefund.PaymentIssuedDateTime))) + ' ' + LTRIM(SubString(Convert(Varchar,PaymentRefund.PaymentIssuedDateTime,22),10,5) + ' ' + Right(Convert(Varchar,PaymentRefund.PaymentIssuedDateTime,22),2)) IssuedDate,

@RefundLogSortOrder                    AS RefundLogSortOrderHeader,
@HeaderDateStart                       AS DrawerCloseStartDateTime,
@HeaderDateEnd                         AS DrawerCloseEndDateTime,
Replace(@PaymentStatusIDList,'|',', ') AS SelectedPaymentStatus,
CASE WHEN @RefundLogSortOrder = 'By Club and Payee Name'
        THEN Club.ClubName + '-' + PaymentRefundContact.LastName + ', ' + PaymentRefundContact.FirstName
            ELSE CONVERT(VARCHAR,MMSTran.PostDateTime,121)
     END AS ReportSortingValue
FROM #RefundTranIDs
--Join vMMSTranRefund as MMSTranRefund
 --On #RefundTranIDs.MMSTranID = MMSTranRefund.MMSTranID
Join #MMSTran as MMSTran
 On #RefundTranIDs.MMSTranID = MMSTran.MMSTranID
Join vClub as Club
 On Club.ClubID = MMSTran.RequestingClubID
Join vMember as Member
On Member.MemberID = MMSTran.MemberID
Join vValCurrencyCode ValCurrencyCode
On ISNULL(MMSTran.ValCurrencyCodeID,1)  = ValCurrencyCode.ValCurrencyCodeID
Join vPayment as Payment
 On MMSTran.MMSTranID = Payment.MMSTranID
Join vPaymentRefund as PaymentRefund
 On Payment.PaymentID = PaymentRefund.PaymentID
Join vPaymentRefundContact as PaymentRefundContact
 On PaymentRefundContact.PaymentRefundID = PaymentRefund.PaymentRefundID
Join vValState as ValState
 On PaymentRefundContact.ValStateID = ValState.ValStateID
Join vValCountry as ValCountry
 On PaymentRefundContact.ValCountryID = ValCountry.ValCountryID
Join #RefundAccountCodes
 On MMSTran.MMSTranID = #RefundAccountCodes.MMSTranID
Join vValPaymentStatus ValPaymentStatus
 On PaymentRefund.ValPaymentStatusID = ValPaymentStatus.ValPaymentStatusID

WHERE Payment.ValPaymentTypeID = 2
AND PaymentRefund.ValPaymentStatusID IN (Select StatusID From #StatusList)
ORDER BY ReportSortingValue

-- Droping a Temp tables
 
DROP TABLE  #tmpList
DROP TABLE  #StatusList
DROP TABLE  #RefundTranIDs
DROP TABLE  #RefundAccountCodes
DROP TABLE  #MMSTran

END


