

CREATE PROC [dbo].[procCognos_DelinquentAging_PaymentsAndAdjustments_MTD] (
    @StartDate DATETIME,
	@RegionList VARCHAR(8000),
    @ClubIDList VARCHAR(8000),
    @DelinquentStatusList VARCHAR(100),
    @MembershipStatusList VARCHAR(1000),
    @TransactionTypeList VARCHAR(100),
	@TransactionReasonCodeIDList VARCHAR(4000)
)

AS
BEGIN 
SET XACT_ABORT ON
SET NOCOUNT ON

IF 1=0 BEGIN
       SET FMTONLY OFF
     END

  -------------
  ------ Sample execution 
  ------ Exec procCognos_DelinquentAging_PaymentsAndAdjustments_MTD '2/28/2017','All Regions','151','0-30|31-60|61-90','Active|Late Activation|Suspended|Non-Paid|Non-Paid Late Activation|Pending Termination|Terminated','Adjustment|Payment|Refund','-1'
  -------------


DECLARE @ReportDate DATETIME
SET @ReportDate = CASE WHEN @StartDate = 'Jan 1, 1900' THEN DATEADD(d,-1,DATEADD(mm, DATEDIFF(m,0,GETDATE())+1,0)) ELSE @StartDate END  --Last Day of the Month

 ----- Declare variables and temp tables
DECLARE @FirstOfReportMonth DateTime
DECLARE @SecondOfReportMonth DateTime
DECLARE @ReportDatePlus1 DateTime
DECLARE @FirstOfNextMonth DateTime
DECLARE @FirstOf3MonthsPrior DateTime
SET @FirstOfReportMonth = (SELECT CalendarMonthStartingDate 
                             FROM vReportDimDate 
							 WHERE CalendarDate = @ReportDate)
SET @SecondOfReportMonth = DATEADD(day,1,@FirstOfReportMonth)
SET @ReportDatePlus1 = DATEADD(Day,1,@ReportDate)
SET @FirstOfNextMonth = DATEADD(Month,1,@FirstOfReportMonth)
SET @FirstOf3MonthsPrior = DATEADD(Month,-3,@FirstOfReportMonth)

CREATE TABLE #tmpList (StringField VARCHAR(50))
CREATE TABLE #DelinquentStatusList (DelinquentStatus VARCHAR(50))
EXEC procParseStringList @DelinquentStatusList 
INSERT INTO #DelinquentStatusList (DelinquentStatus) SELECT StringField FROM #tmpList
TRUNCATE TABLE #tmpList

CREATE TABLE #MembershipStatusList (MembershipStatus VARCHAR(50))
EXEC procParseStringList @MembershipStatusList
INSERT INTO #MembershipStatusList (MembershipStatus) SELECT StringField FROM #tmpList
TRUNCATE TABLE #tmpList

CREATE TABLE #TransactionTypeList (TransactionType VARCHAR(50))
EXEC procParseStringList @TransactionTypeList
INSERT INTO #TransactionTypeList (TransactionType) SELECT StringField FROM #tmpList
TRUNCATE TABLE #tmpList

SELECT Convert(Integer,item) ReasonCodeID
  INTO #ReasonCodeIDList
  FROM fnParsePipeList(@TransactionReasonCodeIDList)

DECLARE @PossibleReasonCodeCount INT
DECLARE @SelectedReasonCodeCount INT
SET @PossibleReasonCodeCount = (Select Count(ReasonCodeID) from vReasonCode)
SET @SelectedReasonCodeCount = (Select Count(ReasonCodeID) from #ReasonCodeIDList)

DECLARE @HeaderTransactionReason VARCHAR(50)
SELECT @HeaderTransactionReason = CASE WHEN MIN(#ReasonCodeIDList.ReasonCodeID) = -1 THEN 'All Transaction Reasons'
                                       WHEN @PossibleReasonCodeCount = @SelectedReasonCodeCount THEN 'All Transaction Reasons'
                                       WHEN COUNT(*) = 1 THEN Min(ReasonCode.Description)
                                       ELSE 'Multiple Transaction Reasons' END
  FROM vReasonCode ReasonCode
  JOIN #ReasonCodeIDList
    ON ReasonCode.ReasonCodeID = #ReasonCodeIDList.ReasonCodeID
	 OR #ReasonCodeIDList.ReasonCodeID = -1


SELECT DISTINCT Club.ClubID as ClubID
  INTO #Clubs
  FROM vClub Club
  JOIN fnParsePipeList(@ClubIDList) MMSClubIDList
    ON Convert(Varchar,Club.ClubID) = MMSClubIDList.Item
    OR @ClubIDList like '%All Clubs%'
  JOIN vValRegion Region
    ON Club.ValRegionID = Region.ValRegionID
  JOIN fnParsePipeList(@RegionList) RegionList
    ON Region.Description = RegionList.Item
    OR @RegionList like '%All Regions%'

DECLARE @ReportRunDateTime VARCHAR(21)
DECLARE @HeaderMembershipStatusList  VARCHAR(1000)
DECLARE @HeaderDelinquentStatusList VARCHAR(100)
DECLARE @HeaderTransactionTypeList VARCHAR(100)

SET @ReportRunDateTime = Replace(Substring(convert(varchar,GetDate(),100),1,6)+', '+Substring(convert(varchar,GetDate(),100),8,10)+' '+Substring(convert(varchar,GetDate(),100),18,2),'  ',' ')

SET @HeaderMembershipStatusList = STUFF((SELECT DISTINCT ', ' + tMSL.MembershipStatus
                                       FROM #MembershipStatusList tMSL                                 
                                       FOR XML PATH('')),1,1,'') 
SET @HeaderDelinquentStatusList = STUFF((SELECT DISTINCT ', ' + tDSL.DelinquentStatus
                                       FROM #DelinquentStatusList tDSL                                 
                                       FOR XML PATH('')),1,1,'')    
SET @HeaderTransactionTypeList = STUFF((SELECT DISTINCT ', ' + tTTL.TransactionType
                                       FROM #TransactionTypeList tTTL                                 
                                       FOR XML PATH('')),1,1,'')    

  --- Find all membership IDs for selected parameters - 
Select MA.MembershipID,MA.AttributeValue AS DelinquentMembershipAging,
MA.InsertedDateTime, MA.EffectiveFromDateTime, MA.EffectiveThruDateTime,
MembershipRegion.Description AS MMSRegion, MembershipClub.ClubCode,
MembershipClub.ClubName
INTO #DelinquentMembershipIDs
FROM vMembershipAttribute MA
JOIN #DelinquentStatusList DSL
  ON MA.AttributeValue = DSL.DelinquentStatus
JOIN vMembership MS
  ON MA.MembershipID = MS.MembershipID
JOIN #Clubs Club
  ON MS.ClubID = Club.ClubID
JOIN vValMembershipStatus VMS
  ON MS.ValMembershipStatusID = VMS.ValMembershipStatusID
JOIN #MembershipStatusList MSL
  ON VMS.Description = MSL.MembershipStatus
JOIN vClub MembershipClub
  ON Club.ClubID = MembershipClub.ClubID
JOIN vValRegion MembershipRegion
  ON MembershipClub.ValRegionID = MembershipRegion.ValRegionID
WHERE ((MA.InsertedDateTime >= @FirstOfReportMonth AND MA.InsertedDateTime < @FirstOfNextMonth)  --- to return all inserts MTD
      OR 
	  (MA.EffectiveFromDateTime <= @FirstOfReportMonth 
	      AND IsNull(MA.EffectiveThruDateTime,@ReportDatePlus1) > @FirstOfReportMonth))  --- to return all carry overs from prior Month
AND MA.ValMembershipAttributeTypeID = 6




------ Find the beginning of the month outstanding balance for these memberships
Select MS.MembershipID, M.MemberID AS PrimaryMemberID,
       MT.AttributeValue AS FirstOfMonthDuesBalance
	INTO #DuesBalanceBOM
from vMembership MS
 JOIN #DelinquentMembershipIDs  DEL
   ON MS.MembershipID = DEL.MembershipID
 JOIN vMembershipAttribute MT
   ON MS.MembershipID = MT.MembershipID
    AND MT.EffectiveFromDateTime <= @FirstOfReportMonth
	AND IsNull(MT.EffectiveThruDateTime,@ReportDatePlus1) > @FirstOfReportMonth
 Join vMember M
   ON MS.MembershipID = M.MembershipID
    AND M.ValMemberTypeID = 1
 Where MT.ValMembershipAttributeTypeID = 8




  ----- Find all payments on account for selected memberships for 2nd of month through report date
SELECT IDs.MMSRegion, 
       IDs.ClubCode,
	   IDs.ClubName,
	   'Payment' AS TransactionType,
	   MT.PostDateTime,
	   Drawer.CloseDateTime AS MMSDrawerCloseDateTime,
	   NULL AS ProductDescription,
       VPT.Description AS PaymentType,
	   MT.MemberID,
	   TransactionMember.LastName AS MemberLastName,
	   TransactionMember.FirstName AS MemberFirstName,
       IDs.DelinquentMembershipAging,
	   DuesBalance.FirstOfMonthDuesBalance,
	   RC.Description AS TranReason,
       MT.EmployeeID,
	   E.FirstName AS TeamMemberFirstName, 
	   E.LastName AS TeamMemberLastName,
	   EmployeeHomeClub.ClubName  TeamMemberHomeClub,
	   CASE WHEN VPT.Description = 'Cash'       -------- For payments on account, there is no segregated tax amount
         THEN PMT.PaymentAmount - MT.ChangeRendered
	     ELSE PMT.PaymentAmount 
	     END AmountBeforeTax,
	   CASE WHEN VPT.Description = 'Cash'
         THEN PMT.PaymentAmount - MT.ChangeRendered
	     ELSE PMT.PaymentAmount 
	     END  AmountAfterTax,
	   ReasonCode.Description TransactionReason,
	   MT.MembershipID
INTO #AllTransactions
FROM vMMSTran MT
JOIN #DelinquentMembershipIDs IDs
  ON MT.MembershipID = IDs.MembershipID
JOIN vEmployee E
  ON MT.EmployeeID = E.EmployeeID
JOIN vReasonCode RC
  ON MT.ReasonCodeID = RC.ReasonCodeID
JOIN vPayment PMT
  ON MT.MMSTranID = PMT.MMSTranID
JOIN vValPaymentType VPT
  ON PMT.ValPaymentTypeID = VPT.ValPaymentTypeID
JOIN vDrawerActivity Drawer
  ON MT.DrawerActivityID = Drawer.DrawerActivityID
JOIN vMember TransactionMember
  ON MT.MemberID = TransactionMember.MemberID
JOIN vClub EmployeeHomeClub
  ON E.ClubID = EmployeeHomeClub.ClubID
JOIN vReasonCode ReasonCode
  ON MT.ReasonCodeID = ReasonCode.ReasonCodeID
JOIN vValTranType TranType
  ON MT.ValTranTypeID = TranType.ValTranTypeID
JOIN #TransactionTypeList TranTypeList
  ON TranType.Description = TranTypeList.TransactionType

LEFT JOIN #DuesBalanceBOM  DuesBalance
  ON IDS.MembershipID = DuesBalance.MembershipID
WHERE MT.ValTranTypeID = 2
  AND MT.TranDate >= @SecondOfReportMonth
  AND MT.TranDate < @ReportDatePlus1
  AND IsNull(MT.TranVoidedID,0) = 0
  AND TranTypeList.TransactionType = 'Payment' 




UNION ALL


   ----- Find all adjustments for selected memberships for 2nd of month through report date
SELECT IDs.MMSRegion, 
       IDs.ClubCode,
	   IDs.ClubName,
	   'Adjustment' AS TransactionType,
	   MT.PostDateTime,
	   Drawer.CloseDateTime AS MMSDrawerCloseDateTime,
	   Product.Description AS ProductDescription,
       NULL AS PaymentType,
	   MT.MemberID,
	   TransactionMember.LastName AS MemberLastName,
	   TransactionMember.FirstName AS MemberFirstName,
       IDs.DelinquentMembershipAging,
	   DuesBalance.FirstOfMonthDuesBalance,
	   RC.Description AS TranReason,
       MT.EmployeeID,
	   E.FirstName AS TeamMemberFirstName, 
	   E.LastName AS TeamMemberLastName,
	   EmployeeHomeClub.ClubName TeamMemberHomeClub,
	   CASE WHEN IsNull(TranItem.ItemAmount,0) = 0
         THEN MT.TranAmount
	     ELSE TranItem.ItemAmount 
	     END  AmountBeforeTax,
	   MT.TranAmount AS  AmountAfterTax,
	   ReasonCode.Description TransactionReason,
	   MT.MembershipID

FROM vMMSTran MT
JOIN #DelinquentMembershipIDs IDs
  ON MT.MembershipID = IDs.MembershipID
JOIN vEmployee E
  ON MT.EmployeeID = E.EmployeeID
JOIN vReasonCode RC
  ON MT.ReasonCodeID = RC.ReasonCodeID
JOIN vDrawerActivity Drawer
  ON MT.DrawerActivityID = Drawer.DrawerActivityID
JOIN vMember TransactionMember
  ON MT.MemberID = TransactionMember.MemberID
JOIN vClub EmployeeHomeClub
  ON E.ClubID = EmployeeHomeClub.ClubID
JOIN vReasonCode ReasonCode
  ON MT.ReasonCodeID = ReasonCode.ReasonCodeID
JOIN vValTranType TranType
  ON MT.ValTranTypeID = TranType.ValTranTypeID
JOIN #TransactionTypeList TranTypeList
  ON TranType.Description = TranTypeList.TransactionType

LEFT JOIN vTranItem TranItem
  ON MT.MMSTranID = TranItem.MMSTranID
LEFT JOIN vProduct Product
  ON TranItem.ProductID = Product.ProductID
LEFT JOIN #DuesBalanceBOM  DuesBalance
  ON IDS.MembershipID = DuesBalance.MembershipID
WHERE MT.ValTranTypeID = 4
  AND MT.TranDate >= @SecondOfReportMonth
  AND MT.TranDate < @ReportDatePlus1
  AND IsNull(MT.TranVoidedID,0) = 0
  AND TranTypeList.TransactionType = 'Adjustment' 


UNION ALL


   ----- Find all refunds for selected memberships for 2nd of month through report date

SELECT IDs.MMSRegion, 
       IDs.ClubCode,
	   IDs.ClubName,
	   'Refund' AS TransactionType,
	   MT.PostDateTime,
	   Drawer.CloseDateTime AS MMSDrawerCloseDateTime,
	   Product.Description AS ProductDescription,
       NULL AS PaymentType,
	   MT.MemberID,
	   TransactionMember.LastName AS MemberLastName,
	   TransactionMember.FirstName AS MemberFirstName,
       IDs.DelinquentMembershipAging,
	   DuesBalance.FirstOfMonthDuesBalance,
	   RC.Description AS TranReason,
       MT.EmployeeID,
	   E.FirstName AS TeamMemberFirstName, 
	   E.LastName AS TeamMemberLastName,
	   EmployeeHomeClub.ClubName TeamMemberHomeClub,
       TranItem.ItemAmount AS AmountBeforeTax, 
	   TranItem.ItemAmount + TranItem.ItemSalesTax AS  AmountAfterTax,
	   ReasonCode.Description TransactionReason,
	   MT.MembershipID

FROM vMMSTran MT
JOIN #DelinquentMembershipIDs IDs
  ON MT.MembershipID = IDs.MembershipID
JOIN vEmployee E
  ON MT.EmployeeID = E.EmployeeID
JOIN vReasonCode RC
  ON MT.ReasonCodeID = RC.ReasonCodeID
JOIN vDrawerActivity Drawer
  ON MT.DrawerActivityID = Drawer.DrawerActivityID
JOIN vMember TransactionMember
  ON MT.MemberID = TransactionMember.MemberID
JOIN vClub EmployeeHomeClub
  ON E.ClubID = EmployeeHomeClub.ClubID
JOIN vReasonCode ReasonCode
  ON MT.ReasonCodeID = ReasonCode.ReasonCodeID
JOIN vValTranType TranType
  ON MT.ValTranTypeID = TranType.ValTranTypeID
JOIN #TransactionTypeList TranTypeList
  ON TranType.Description = TranTypeList.TransactionType

LEFT JOIN vTranItem TranItem
  ON MT.MMSTranID = TranItem.MMSTranID
LEFT JOIN vProduct Product
  ON TranItem.ProductID = Product.ProductID
LEFT JOIN #DuesBalanceBOM  DuesBalance
  ON IDS.MembershipID = DuesBalance.MembershipID
WHERE MT.ValTranTypeID = 5
  AND MT.TranDate >= @SecondOfReportMonth
  AND MT.TranDate < @ReportDatePlus1
  AND IsNull(MT.TranVoidedID,0) = 0
  AND TranTypeList.TransactionType = 'Refund' 


  Select MMSRegion, 
         ClubCode,
	     ClubName,
	     TransactionType,
	     PaymentType,
		 MMSDrawerCloseDateTime,
		 PostDateTime,
	     ProductDescription,
	     AmountBeforeTax,
	     AmountAfterTax,		 
		 MemberID,
	     MemberLastName,
	     MemberFirstName,
         DelinquentMembershipAging,
		 FirstOfMonthDuesBalance,
         EmployeeID AS TransactionTeamMemberID,
	     TeamMemberFirstName, 
	     TeamMemberLastName,
	     TeamMemberHomeClub,
		 TransactionReason,
		 @ReportDate AS HeaderReportDate,
		 @SecondOfReportMonth AS HeaderSecondOfReportMonth,
		 @ReportRunDateTime AS ReportRunDateTime,
		 @HeaderMembershipStatusList AS HeaderMembershipStatusList, 
         @HeaderDelinquentStatusList AS HeaderDelinquentStatusList,
		 @HeaderTransactionTypeList AS HeaderTransactionTypeList,
		 @HeaderTransactionReason AS HeaderTransactionReason,
		 MembershipID
  FROM #AllTransactions





DROP TABLE #tmpList
DROP TABLE #DelinquentStatusList
DROP TABLE #MembershipStatusList
DROP TABLE #Clubs
DROP TABLE #DelinquentMembershipIDs
DROP TABLE #AllTransactions
DROP TABLE #DuesBalanceBOM
DROP TABLE #TransactionTypeList
DROP TABLE #ReasonCodeIDList


END


