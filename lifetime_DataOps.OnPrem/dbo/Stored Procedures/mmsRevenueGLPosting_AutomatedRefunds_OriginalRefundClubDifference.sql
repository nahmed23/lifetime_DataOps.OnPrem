

-- Added ValPaymentTypeIDs 9,10, and 13 to the result set -- BSD 10/21/2010 QC 5843 
-- changed stored procedure by adding 2 parameters: month and year   --- RC 06/11/2009
--
--v


-- execute [mmsRevenueGLPosting_AutomatedRefunds_OriginalRefundClubDifference] '5','2009'

CREATE PROCEDURE [dbo].[mmsRevenueGLPosting_AutomatedRefunds_OriginalRefundClubDifference] 
(
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

--	DECLARE @FirstOfMonth DATETIME
--	SET @FirstOfMonth  =  CONVERT(DATETIME, SUBSTRING(CONVERT(VARCHAR,dateadd(mm,0,GETDATE()),112),1,6) + '01', 112)
--	SET @PostDateStart  =  dateadd(mm,-1,@firstofmonth)
--	SET @PostDateEnd  =  dateadd(ss,-1,@firstofmonth)

-- returns data on all unvoided automated refund transactions from closed drawers, 
-- posted in the requested month with the transaction reason of “30 Day Cancellation” 
CREATE TABLE #30DayCancellationRefundHomeClub (
MMSTranRefundID INT,
MembershipGLClubID INT,
MembershipClubName NVARCHAR(50))
INSERT INTO #30DayCancellationRefundHomeClub
SELECT 
	MMSTR.MMSTranRefundID,
	C.GLClubID,
	C.ClubName
FROM vMMSTranRefund MMSTR
	JOIN vMMSTran MMST ON MMST.MMSTranID = MMSTR.MMSTranID
	JOIN vMembership MS ON MS.MembershipID = MMST.MembershipID
	JOIN vClub C ON C.ClubID = MS.ClubID
	JOIN vDrawerActivity DA ON DA.DrawerActivityID = MMST.DrawerActivityID 
WHERE 
	-- exclude voided transactions
	MMST.TranVoidedID is null 
	-- transaction reason of “30 Day Cancellation” 
	AND MMST.ReasoncodeID = 108 
	-- closed drawers only
	AND DA.ValDrawerStatusID = 3
	-- requested month
	AND MMST.PostDateTime >= @PostDateStart AND MMST.PostDateTime <= @PostDateEnd


-- refunds for non 30 day cancellations from requested month
CREATE TABLE #Non30DayCancellationRefundTransactions (
	MMSTranRefundID INT
)
INSERT INTO #Non30DayCancellationRefundTransactions
SELECT 
	MMSTR.MMSTranRefundID
FROM vMMSTranRefund MMSTR
	JOIN vMMSTran MMST ON MMST.MMSTranID = MMSTR.MMSTranID
	JOIN vDrawerActivity DA ON DA.DrawerActivityID = MMST.DrawerActivityID 
WHERE 
	-- exclude voided transactions
	MMST.TranVoidedID is null 
	-- transaction reason that are not “30 Day Cancellation” 
	AND MMST.ReasoncodeID <> 108 
	-- closed drawers only
	AND DA.ValDrawerStatusID = 3
	-- requested month
	AND MMST.PostDateTime >= @PostDateStart AND MMST.PostDateTime <= @PostDateEnd


-- returs the original transaction club ID and Name for all refunds gathered in #Non30DayCancellationRefundTransactions
CREATE TABLE #OriginalTranClub_Non30DayCancellations (
MMSTranRefundID INT,
MMSTranID INT,
OriginalMMSTranID INT,
OriginalMMSTran_GLClubID INT,
OriginalMMSTran_ClubName NVARCHAR(50))
INSERT INTO #OriginalTranClub_Non30DayCancellations
SELECT --distinct
	MMSTR.MMSTranRefundID,
	MMSTR.MMSTranID,
	MMSTRT.OriginalMMSTranID,
	C.GLClubID as OriginalMMSTran_GLClubID,
	C.ClubName as OriginalMMSTran_ClubName
FROM vMMSTranRefund MMSTR
	JOIN #Non30DayCancellationRefundTransactions #Non30Day ON #Non30Day.MMSTranRefundID = MMSTR.MMSTranRefundID
	JOIN vMMSTranRefundMMSTran MMSTRT ON MMSTRT.MMSTranRefundID = MMSTR.MMSTranRefundID
	JOIN vMMSTran MMST ON MMST.MMSTranID = MMSTRT.OriginalMMSTranID
	JOIN vClub C ON C.ClubID = MMST.ClubID 


  -- returns a summarized list grouped and totaled by Charged Club within Refunding club 
  -- Where the Charged Club is the Membership Home Club for 30 Day Cancellation refunds and the Original Transaction Club for all other refunds.
	SELECT 
	RefundingClub_GLClubID,
	Refunding_Club,  
	ChargedClub_GLCLubID,
	Charged_Club,
	SUM(Amount) as Amount,
	datename(month,@PostDateStart)+' '+ datename(year, @PostDateStart) AS ReportMonthYear,
	PaymentType
	FROM
	(
	SELECT 
	MMST.ClubID AS RefundingClubID,
	C.GLClubID as RefundingClub_GLClubID,
	C.ClubName as Refunding_Club,  
	#Non30DC.OriginalMMSTran_GLClubID,
	CASE WHEN #30DC.MembershipGLClubID is Null THEN #Non30DC.OriginalMMSTran_GLClubID ELSE #30DC.MembershipGLClubID END AS ChargedClub_GLCLubID,
	CASE WHEN #30DC.MembershipClubName is Null THEN #Non30DC.OriginalMMSTran_ClubName ELSE #30DC.MembershipClubName END AS Charged_Club,
	CASE C.GLClubID 
		WHEN #30DC.MembershipGLClubID          THEN 0
		WHEN #Non30DC.OriginalMMSTran_GLClubID THEN 0
		ELSE P.PaymentAmount END AS Amount,
	VPT.Description as PaymentType
	FROM vMMSTranRefund MMSTR 
		LEFT JOIN #OriginalTranClub_Non30DayCancellations #Non30DC ON #Non30DC.MMSTranRefundID = MMSTR.MMSTranRefundID
		LEFT JOIN #30DayCancellationRefundHomeClub #30DC ON #30DC.MMSTranRefundID = MMSTR.MMStranRefundID
		-- refund transactions only  
		JOIN vMMSTran MMST ON MMST.MMSTranID = MMSTR.MMSTranID
		JOIN vClub C ON C.ClubID = MMST.ClubID
		JOIN vDrawerActivity DA ON DA.DrawerActivityID = MMST.DrawerActivityID 
		JOIN vPayment P ON P.MMSTranID = MMST.MMSTranID
		JOIN vValPaymentType VPT ON P.ValPaymentTypeID = VPT.ValPaymentTypeID
	WHERE 
		P.ValPaymentTypeID IN (3,4,5,8,9,10,13)
		AND MMST.PostDateTime >= @PostDateStart AND MMST.PostDateTime <= @PostDateEnd
		AND MMST.TranVoidedid is null
	) as T1
	GROUP BY 
	RefundingClub_GLClubID,
	Refunding_Club,  
	ChargedClub_GLCLubID,
	Charged_Club,
	PaymentType


	DROP TABLE #30DayCancellationRefundHomeClub
	DROP TABLE #Non30DayCancellationRefundTransactions 
	DROP TABLE #OriginalTranClub_Non30DayCancellations


-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END

