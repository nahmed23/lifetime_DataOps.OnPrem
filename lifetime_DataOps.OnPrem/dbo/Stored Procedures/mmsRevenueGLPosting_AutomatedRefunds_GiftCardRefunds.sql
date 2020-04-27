
CREATE PROCEDURE [dbo].[mmsRevenueGLPosting_AutomatedRefunds_GiftCardRefunds] (
	@Month varchar(2), -- requested month
	@Year varchar(4)  -- requested year
) 
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
DECLARE @Identity AS INT
INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
SET @Identity = @@IDENTITY

DECLARE @DateStart varchar(10)
DECLARE @PostDateStart DATETIME
DECLARE @PostDateEND DATETIME

SET @DateStart = @Month +'/1/' + @Year
SET @PostDateStart  =  cast(@DateStart as datetime)
SET @PostDateEnd  =  dateadd(ss,-1,(dateadd(mm,1,@PostDateStart)))

-- returns data on all unvoided automated refund transactions from closed drawers, 
-- posted in the requested month with the transaction reason of “30 Day Cancellation” 
SELECT MMSTR.MMSTranRefundID,
       C.ClubID MembershipClubID,
	   C.GLClubID MembershipGLClubID,
	   C.ClubName MembershipClubName
INTO #30DayCancellationRefundHomeClub
FROM vMMSTranRefund MMSTR
JOIN vMMSTran MMST ON MMST.MMSTranID = MMSTR.MMSTranID
JOIN vMembership MS ON MS.MembershipID = MMST.MembershipID
JOIN vClub C ON C.ClubID = MS.ClubID
JOIN vDrawerActivity DA ON DA.DrawerActivityID = MMST.DrawerActivityID 
WHERE MMST.TranVoidedID is null -- exclude voided transactions
  AND MMST.ReasoncodeID = 108 -- transaction reason of “30 Day Cancellation” 
  AND DA.ValDrawerStatusID = 3 -- closed drawers only
  AND MMST.PostDateTime >= @PostDateStart AND MMST.PostDateTime <= @PostDateEnd -- requested month

-- refunds for non 30 day cancellations from requested month
SELECT MMSTR.MMSTranRefundID
INTO #Non30DayCancellationRefundTransactions
FROM vMMSTranRefund MMSTR
JOIN vMMSTran MMST ON MMST.MMSTranID = MMSTR.MMSTranID
JOIN vDrawerActivity DA ON DA.DrawerActivityID = MMST.DrawerActivityID 
WHERE MMST.TranVoidedID is null -- exclude voided transactions
  AND MMST.ReasoncodeID <> 108 -- transaction reason that are not “30 Day Cancellation”
  AND DA.ValDrawerStatusID = 3 -- closed drawers only
  AND MMST.PostDateTime >= @PostDateStart AND MMST.PostDateTime <= @PostDateEnd -- requested month

-- returns the original transaction club ID and Name for all refunds gathered in #Non30DayCancellationRefundTransactions
SELECT MMSTR.MMSTranRefundID,
	   MMSTR.MMSTranID,
	   MMSTRT.OriginalMMSTranID,
       C.ClubID OriginalMMSTran_ClubID,
	   C.GLClubID OriginalMMSTran_GLClubID,
	   C.ClubName OriginalMMSTran_ClubName
INTO #OriginalTranClub_Non30DayCancellations
FROM vMMSTranRefund MMSTR
JOIN #Non30DayCancellationRefundTransactions #Non30Day ON #Non30Day.MMSTranRefundID = MMSTR.MMSTranRefundID
JOIN vMMSTranRefundMMSTran MMSTRT ON MMSTRT.MMSTranRefundID = MMSTR.MMSTranRefundID
JOIN vMMSTran MMST ON MMST.MMSTranID = MMSTRT.OriginalMMSTranID
JOIN vClub C ON C.ClubID = MMST.ClubID 


-- returns a detailed list of Gift Card returns
-- Where the Charged Club is the Membership Home Club for 30 Day Cancellation refunds and the Original Transaction Club for all other refunds.
SELECT CASE WHEN #30DC.MembershipGLClubID is Null THEN #Non30DC.OriginalMMSTran_ClubID ELSE #30DC.MembershipClubID END ChargeClubID,
       CASE WHEN #30DC.MembershipGLClubID is Null THEN #Non30DC.OriginalMMSTran_GLClubID ELSE #30DC.MembershipGLClubID END ChargeGLClubID,
       CASE WHEN #30DC.MembershipClubName is Null THEN #Non30DC.OriginalMMSTran_ClubName ELSE #30DC.MembershipClubName END ChargeClubName,
       MMST.ClubID RefundClubID,
       C.GLClubID RefundGLClubID,
       C.ClubName RefundClubName,  
       VCC.CurrencyCode RefundLocalCurrencyCode,
       P.PaymentAmount LocalCurrencyRefundAmount,
       USDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate,
       Cast(P.PaymentAmount * USDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate as Numeric(16,6)) USDRefundAmount,
       DATENAME(MONTH,@PostDateStart) + ' ' + DATENAME(YEAR, @PostDateStart) ReportMonthYear
FROM vMMSTranRefund MMSTR 
LEFT JOIN #OriginalTranClub_Non30DayCancellations #Non30DC ON #Non30DC.MMSTranRefundID = MMSTR.MMSTranRefundID
LEFT JOIN #30DayCancellationRefundHomeClub #30DC ON #30DC.MMSTranRefundID = MMSTR.MMStranRefundID
JOIN vMMSTran MMST ON MMST.MMSTranID = MMSTR.MMSTranID
JOIN vClub C ON C.ClubID = MMST.ClubID
JOIN vValCurrencyCode VCC ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID
JOIN vMonthlyAverageExchangeRate USDMonthlyAverageExchangeRate
  ON VCC.CurrencyCode = USDMonthlyAverageExchangeRate.FromCurrencyCode
 AND 'USD' = USDMonthlyAverageExchangeRate.ToCurrencyCode
 AND MMST.PostDateTime >= USDMonthlyAverageExchangeRate.FirstOfMonthDate
 AND Convert(Datetime,Convert(Varchar,MMST.PostDateTime,101),101) <= USDMonthlyAverageExchangeRate.EndOfMonthDate
JOIN vDrawerActivity DA ON DA.DrawerActivityID = MMST.DrawerActivityID 
JOIN vPayment P ON P.MMSTranID = MMST.MMSTranID
WHERE P.ValPaymentTypeID IN (14) -- gift cards only
  AND MMST.PostDateTime >= @PostDateStart AND MMST.PostDateTime <= @PostDateEnd
  AND MMST.TranVoidedid is null
  AND DA.ValDrawerStatusID = 3 -- closed drawers only

DROP TABLE #30DayCancellationRefundHomeClub
DROP TABLE #Non30DayCancellationRefundTransactions 
DROP TABLE #OriginalTranClub_Non30DayCancellations

END
