




CREATE PROC [dbo].[procCognos_TransactionClubDetailByTransactionType] (
 @ReportStartDate DATETIME,
 @ReportEndDate DATETIME,
 @MMSClubIDList VARCHAR(4000),
 @RegionList VARCHAR(4000),
 @SalesSourceList VARCHAR(4000),
 @TransactionTypeList VARCHAR(4000),
 @TransactionReasonCodeIDList VARCHAR(4000),
 @TotalTransactionReasonCount INT,
 @MembershipFilter VARCHAR(50))

AS
BEGIN 
SET XACT_ABORT ON
SET NOCOUNT ON


------ Sample Execution
--- Exec procCognos_TransactionClubDetailByTransactionType '2/3/2017','3/3/2017','All Clubs','All Regions','MMS','Adjustment','108|205|146|203|102|110|77|83',6,'All Memberships' 
------



SET @ReportStartDate = CASE WHEN @ReportStartDate = 'Jan 1, 1900' THEN DATEADD(MONTH,DATEDIFF(MONTH,0,GETDATE()-1),0) ELSE @ReportStartDate END
SET @ReportEndDate = CASE WHEN @ReportEndDate = 'Jan 1, 1900' THEN CONVERT(DATETIME,CONVERT(VARCHAR,GETDATE()-1,101),101) ELSE @ReportEndDate END


DECLARE @Today DATETIME
DECLARE @HeaderDateRange Varchar(110)
DECLARE @ReportRunDateTime VARCHAR(21)
DECLARE @DuesAssessmentStartDate DateTime
DECLARE @DuesAssessmentEndDate DateTime



SET @HeaderDateRange = Replace(Substring(convert(varchar,@ReportStartDate,100),1,6)+', '+Substring(convert(varchar,@ReportStartDate,100),8,4),'  ',' ')
                       + ' through ' + 
                       Replace(Substring(convert(varchar,@ReportEndDate,100),1,6)+', '+Substring(convert(varchar,@ReportEndDate,100),8,4),'  ',' ')
SET @ReportRunDateTime = Replace(Substring(convert(varchar, GetDate(), 100),1,6)+', '+Substring(convert(varchar, GetDate(), 100),8,10)+' '+Substring(convert(varchar,GetDate(), 100),18,2),'  ',' ')

SET @Today = CONVERT(Datetime,CONVERT(Varchar,GetDate(),101),101)
SET @DuesAssessmentStartDate = (SELECT CalendarMonthStartingDate FROM vReportDimDate WHERE CalendarDate = @Today)
SET @DuesAssessmentEndDate = (SELECT CalendarDate FROM vReportDimDate WHERE CalendarDate = DateAdd(day,1,@DuesAssessmentStartDate))



SELECT DISTINCT Club.ClubID as MMSClubID
  INTO #MMSClubIDList
  FROM vClub Club
  JOIN fnParsePipeList(@MMSClubIDList) MMSClubIDList
    ON Convert(Varchar,Club.ClubID) = MMSClubIDList.Item
    OR @MMSClubIDList like '%All Clubs%'
  JOIN vValRegion Region
    On Club.ValRegionID = Region.ValRegionID
  JOIN fnParsePipeList(@RegionList) RegionList
    ON Region.Description = RegionList.Item
    OR @RegionList like '%All Regions%'
  

SELECT item SalesSource
  INTO #SalesSourceList
  FROM fnParsePipeList(@SalesSourceList)

SELECT ValTranType.ValTranTypeID
  INTO #ValTranTypeIDList
  FROM fnParsePipeList(@TransactionTypeList) TransactionTypeList
  JOIN vValTranType ValTranType
    ON TransactionTypeList.Item = ValTranType.Description

SELECT Convert(Integer,item) ReasonCodeID
  INTO #ReasonCodeIDList
  FROM fnParsePipeList(@TransactionReasonCodeIDList)

DECLARE @SalesSourceCommaList VARCHAR(4000)
SET @SalesSourceCommaList = Replace(@SalesSourceList,'|',',')

DECLARE @TransactionTypeCommaList VARCHAR(4000)
SET @TransactionTypeCommaList = Replace(@TransactionTypeList,'|',',')

DECLARE @HeaderTransactionReason VARCHAR(50)
SELECT @HeaderTransactionReason = CASE WHEN #ReasonCodeIDList.ReasonCodeID = -1 THEN 'All Transaction Reasons'
                                       WHEN COUNT(*) = @TotalTransactionReasonCount THEN 'All Transaction Reasons'
                                       WHEN COUNT(*) = 1 THEN Min(ReasonCode.Description)
                                       ELSE 'Multiple Transaction Reasons' END
  FROM vReasonCode ReasonCode
  JOIN #ReasonCodeIDList
    ON ReasonCode.ReasonCodeID = #ReasonCodeIDList.ReasonCodeID
	 OR #ReasonCodeIDList.ReasonCodeID = -1
  GROUP BY #ReasonCodeIDList.ReasonCodeID 

DECLARE @CurrencyCode VARCHAR(15)
SELECT @CurrencyCode = 'Local Currency' 

CREATE TABLE #Results (
MMSTranID INT,
TranItemID INT,
Region VARCHAR(50),
ClubCode VARCHAR(18),
ClubName VARCHAR(50),
ClubID INT,
TransactionType VARCHAR(10),
MMSPostDate VARCHAR(12),
MMSDrawerCloseDate VARCHAR(12),
CafeCloseDate VARCHAR(12),
CafePostDate VARCHAR(12),
ECommerceOrderDate VARCHAR(12),
ECommerceShipmentDate VARCHAR(12),
EDWInsertedDate VARCHAR(12),
Source VARCHAR(10),
SourceProductID VARCHAR(61),
ProductDescription VARCHAR(50),
PaymentTypes VARCHAR(4000),
MemberID INT,
MemberName VARCHAR(132),
TransactionReason VARCHAR(50),
TransactionTeamMemberID INT,
TransactionTeamMemberName VARCHAR(102),
TransactionTeamMemberHomeClub VARCHAR(50),
CommissionedTeamMember1ID INT,
CommissionedTeamMember1Name VARCHAR(102),
CommissionedTeamMember1HomeClub VARCHAR(50),
CommissionedTeamMember2ID INT,
CommissionedTeamMember2Name VARCHAR(102),
CommissionedTeamMember2HomeClub VARCHAR(50),
SalesQuantity INT,
SNSFlag CHAR(1),
GrossTransactionAmount DECIMAL(12,2),
TotalDiscountAmount DECIMAL(12,2),
SalesTax DECIMAL(12,2),
TotalAmount DECIMAL(12,2),
DiscountAmount1 DECIMAL(12,2),
DiscountAmount2 DECIMAL(12,2),
DiscountAmount3 DECIMAL(12,2),
DiscountAmount4 DECIMAL(12,2),
DiscountAmount5 DECIMAL(12,2),
Discount1 VARCHAR(50),
Discount2 VARCHAR(50),
Discount3 VARCHAR(50),
Discount4 VARCHAR(50),
Discount5 VARCHAR(50),
TransactionDate DATETIME,
SalesChannel VARCHAR(50),
CorporateTransferAmount DECIMAL(12,2),
GLClubID INT,
TransactionComment VARCHAR(255),
MembershipDuesAssessed DECIMAL(12,2),
JuniorDuesAssessed DECIMAL(12,2),
MemberRelationsAdjustmentCategory VARCHAR(50))


IF (@ReportEndDate >= @Today AND ('MMS' IN (SELECT SalesSource FROM #SalesSourceList)))
BEGIN


 ----- get list of all of today's transactions
   SELECT DISTINCT
          MMSTran.MMSTranID, 
          MMSTran.ClubID,
          ISNULL(MMSTran.ValCurrencyCodeID,1) ValCurrencyCodeID,
          MMSTran.PostDateTime,
          MMSTran.ValTranTypeID,
          MMSTran.DrawerActivityID,
          MMSTran.MemberID,
          MMSTran.MembershipID,
          MMSTran.ReasonCodeID,
          MMSTran.EmployeeID,
          MMSTran.TranAmount,
          MMSTran.POSAmount,
          MMSTran.ReverseTranFlag,
		  MMSTran.ReceiptComment AS TransactionComment,
	      CASE WHEN MMSTran.ReasonCodeID IN(269,270,271,273,274)
		       THEN 'Club Adjustments'
			   WHEN MMSTran.ReasonCodeID IN(281,282,283)
			   THEN 'Delinquent Adjustments'
			   WHEN MMSTran.ReasonCodeID IN(49,88,108,125,138,151,206,219,224,250,251,252,268,275,280,284,285,286,287,289,290)
			   THEN 'Corporate Adjustments'
			   ELSE ''
			   END MemberRelationsAdjustmentCategory
     INTO #TodayMMSTran
     FROM vMMSTranNonArchive MMSTran
     JOIN #MMSClubIDList
       ON MMSTran.ClubID = #MMSClubIDList.MMSClubID
       OR MMSTran.ClubID in (9999,13)
     JOIN #ValTranTypeIDList
       ON MMSTran.ValTranTypeID = #ValTranTypeIDList.ValTranTypeID
     JOIN #ReasonCodeIDList
       ON MMSTran.ReasonCodeID = #ReasonCodeIDList.ReasonCodeID
	    OR #ReasonCodeIDList.ReasonCodeID = -1
    WHERE MMSTran.PostDateTime >= @Today


  ---- Assign reporting club
   SELECT #TodayMMSTran.MMSTranID, 
          Membership.ClubID,
          #TodayMMSTran.ValCurrencyCodeID,
          #TodayMMSTran.PostDateTime,
          #TodayMMSTran.ValTranTypeID,
          #TodayMMSTran.DrawerActivityID,
          #TodayMMSTran.MemberID,
          #TodayMMSTran.MembershipID,
          #TodayMMSTran.ReasonCodeID,
          #TodayMMSTran.EmployeeID,
          #TodayMMSTran.TranAmount,
          #TodayMMSTran.POSAmount,
          #TodayMMSTran.ReverseTranFlag,
		  #TodayMMSTran.TransactionComment,
		  #TodayMMSTran.MemberRelationsAdjustmentCategory
     INTO #MMSTran
     FROM #TodayMMSTran
     JOIN vMembership Membership
       ON #TodayMMSTran.MembershipID = Membership.MembershipID
    WHERE #TodayMMSTran.ClubID = 13
   UNION ALL
   SELECT #TodayMMSTran.MMSTranID, 
          ISNULL(TranItem.ClubID, #TodayMMSTran.ClubID) ClubID,
          #TodayMMSTran.ValCurrencyCodeID,
          #TodayMMSTran.PostDateTime,
          #TodayMMSTran.ValTranTypeID,
          #TodayMMSTran.DrawerActivityID,
          #TodayMMSTran.MemberID,
          #TodayMMSTran.MembershipID,
          #TodayMMSTran.ReasonCodeID,
          #TodayMMSTran.EmployeeID,
          #TodayMMSTran.TranAmount,
          #TodayMMSTran.POSAmount,
          #TodayMMSTran.ReverseTranFlag,
		  #TodayMMSTran.TransactionComment,
		  #TodayMMSTran.MemberRelationsAdjustmentCategory
     FROM #TodayMMSTran
     JOIN vTranItem TranItem
       ON #TodayMMSTran.MMSTranID = TranItem.MMSTranID
    WHERE #TodayMMSTran.ClubID = 9999
   UNION ALL
   SELECT #TodayMMSTran.MMSTranID, 
          #TodayMMSTran.ClubID,
          #TodayMMSTran.ValCurrencyCodeID,
          #TodayMMSTran.PostDateTime,
          #TodayMMSTran.ValTranTypeID,
          #TodayMMSTran.DrawerActivityID,
          #TodayMMSTran.MemberID,
          #TodayMMSTran.MembershipID,
          #TodayMMSTran.ReasonCodeID,
          #TodayMMSTran.EmployeeID,
          #TodayMMSTran.TranAmount,
          #TodayMMSTran.POSAmount,
          #TodayMMSTran.ReverseTranFlag,
		  #TodayMMSTran.TransactionComment,
		  #TodayMMSTran.MemberRelationsAdjustmentCategory
     FROM #TodayMMSTran
     JOIN #MMSClubIDList
       ON #TodayMMSTran.ClubID = #MMSClubIDList.MMSClubID
    WHERE #TodayMMSTran.ClubID not in (13,9999)

   SELECT DISTINCT #MMSTran.MMSTranID,
                   ValPaymentType.Description PaymentType
     INTO #MMSPayments
     FROM #MMSTran
     JOIN vPayment Payment
       ON #MMSTran.MMSTranID = Payment.MMSTranID
     JOIN vValPaymentType ValPaymentType
       ON Payment.ValPaymentTypeID = ValPaymentType.ValPaymentTypeID
   
   CREATE TABLE #MMSPaymentTypes (MMSTranID INT, PaymentTypes VARCHAR(4000))
   INSERT INTO #MMSPaymentTypes
   SELECT MMSTranID,
          STUFF((SELECT ', ' + InnerMMSPayment.PaymentType
                   FROM #MMSPayments InnerMMSPayment
                  WHERE OuterMMSPayment.MMSTranID = InnerMMSPayment.MMSTranID
                  ORDER BY InnerMMSPayment.MMSTranID
                  FOR XML PATH('')),1,1,'') AS PaymentTypes
     FROM #MMSPayments OuterMMSPayment
    GROUP BY MMSTranID

   SELECT DiscountRank.TranItemID,
          SUM(CASE WHEN DiscountRank.Ranking = 1 THEN DiscountRank.DiscountAmount ELSE 0 END) DiscountAmount1,
          SUM(CASE WHEN DiscountRank.Ranking = 2 THEN DiscountRank.DiscountAmount ELSE 0 END) DiscountAmount2,
          SUM(CASE WHEN DiscountRank.Ranking = 3 THEN DiscountRank.DiscountAmount ELSE 0 END) DiscountAmount3,
          SUM(CASE WHEN DiscountRank.Ranking = 4 THEN DiscountRank.DiscountAmount ELSE 0 END) DiscountAmount4,
          SUM(CASE WHEN DiscountRank.Ranking = 5 THEN DiscountRank.DiscountAmount ELSE 0 END) DiscountAmount5,
          CASE WHEN MAX(CASE WHEN DiscountRank.Ranking = 1 THEN DiscountRank.ReceiptText ELSE Char(0) END) = Char(0) THEN NULL
               ELSE MAX(CASE WHEN DiscountRank.Ranking = 1 THEN DiscountRank.ReceiptText ELSE Char(0) END) END Discount1,
          CASE WHEN MAX(CASE WHEN DiscountRank.Ranking = 2 THEN DiscountRank.ReceiptText ELSE Char(0) END) = Char(0) THEN NULL
               ELSE MAX(CASE WHEN DiscountRank.Ranking = 2 THEN DiscountRank.ReceiptText ELSE Char(0) END) END Discount2,
          CASE WHEN MAX(CASE WHEN DiscountRank.Ranking = 3 THEN DiscountRank.ReceiptText ELSE Char(0) END) = Char(0) THEN NULL
               ELSE MAX(CASE WHEN DiscountRank.Ranking = 3 THEN DiscountRank.ReceiptText ELSE Char(0) END) END Discount3,
          CASE WHEN MAX(CASE WHEN DiscountRank.Ranking = 4 THEN DiscountRank.ReceiptText ELSE Char(0) END) = Char(0) THEN NULL
               ELSE MAX(CASE WHEN DiscountRank.Ranking = 4 THEN DiscountRank.ReceiptText ELSE Char(0) END) END Discount4,
          CASE WHEN MAX(CASE WHEN DiscountRank.Ranking = 5 THEN DiscountRank.ReceiptText ELSE Char(0) END) = Char(0) THEN NULL
               ELSE MAX(CASE WHEN DiscountRank.Ranking = 5 THEN DiscountRank.ReceiptText ELSE Char(0) END) END Discount5
     INTO #MMSDiscounts
     FROM (SELECT TranItemDiscount.TranItemID, 
                  RANK() OVER (PARTITION BY TranItemDiscount.TranItemID 
                               ORDER BY TranItemDiscount.TranItemDiscountID) Ranking,
                  TranItemDiscount.DiscountAmount,
                  SalesPromotion.ReceiptText
             FROM (SELECT MIN(TranItemDiscount.TranItemID) TranItemID, 
                          MIN(TranItemDiscount.AppliedDiscountAmount) DiscountAmount, 
                          MIN(TranItemDiscount.PricingDiscountID) PricingDiscountID, 
                          MIN(TranItemDiscount.TranItemDiscountID) TranItemDiscountID
                     FROM #MMSTran
                     JOIN vTranItem TranItem
                       ON #MMSTran.MMSTranID = TranItem.MMSTranID
                     JOIN vTranItemDiscount TranItemDiscount
                       ON TranItem.TranItemID = TranItemDiscount.TranItemID
                    GROUP BY TranItemDiscount.TranItemDiscountID) TranItemDiscount
             JOIN vPricingDiscount PricingDiscount
               ON TranItemDiscount.PricingDiscountID = PricingDiscount.PricingDiscountID
             JOIN vSalesPromotion SalesPromotion
               ON PricingDiscount.SalesPromotionID = SalesPromotion.SalesPromotionID) DiscountRank             
    WHERE DiscountRank.Ranking <= 5
    GROUP BY DiscountRank.TranItemID

	------ Find all today's transaction memberships
	SELECT MembershipID
	 INTO #TransactionMembershipIDs
	 FROM #TodayMMSTran
	  GROUP BY MembershipID


   SELECT DISTINCT Membership.MembershipID
     INTO #CorporateMemberships
     FROM vMembership Membership
	 JOIN #TransactionMembershipIDs TranMembershipIDs   ------ Added with REP-4167 to limit result and help with performance
	   ON Membership.MembershipID = TranMembershipIDs.MembershipID
     JOIN vMember Member
       ON Membership.MembershipID = Member.MembershipID
      AND Member.ActiveFlag = 1
     LEFT JOIN vMemberReimbursement MemberReimbursement
       ON Member.MemberID = MemberReimbursement.MemberID
      AND MemberReimbursement.EnrollmentDate < @ReportEndDate + 1
      AND (MemberReimbursement.TerminationDate >= @ReportEndDate + 1 OR IsNull(MemberReimbursement.TerminationDate,'1/1/1900') = '1/1/1900')
     LEFT JOIN vReimbursementProgram ReimbursementProgram
       ON MemberReimbursement.ReimbursementProgramID = ReimbursementProgram.ReimbursementProgramID
    WHERE (IsNull(Membership.CompanyID,0) <> 0 OR ReimbursementProgram.ActiveFlag = 1)



	----- Find Today's assessed membership dues for transaction memberships
	SELECT MMSTran.MembershipID,
	       SUM(MMSTran.TranAmount) as MembershipDuesAssessed
	 INTO #MembershipDues
	 FROM vMMSTran MMSTran
	  JOIN #TransactionMembershipIDs TranMemberships
	    ON MMSTran.MembershipID = TranMemberships.MembershipID
	 WHERE MMSTran.ReasonCodeID = 28  ------ MonthlyDuesAssessment
	  AND MMSTran.PostDateTime >= @DuesAssessmentStartDate
	  AND MMSTran.PostDateTime < @DuesAssessmentEndDate
	  GROUP BY MMSTran.MembershipID




	----- Find Today's assessed Junior dues for transaction memberships
	SELECT MMSTran.MembershipID,
	       SUM(MMSTran.TranAmount) as JuniorDuesAssessed
	  INTO #MembershipJuniorDues
	 FROM vMMSTran MMSTran
	  JOIN #TransactionMembershipIDs TranMemberships
	    ON MMSTran.MembershipID = TranMemberships.MembershipID
	 WHERE MMSTran.ReasonCodeID = 125  ------ JrDuesAssessment
	  AND MMSTran.PostDateTime >= @DuesAssessmentStartDate
	  AND MMSTran.PostDateTime < @DuesAssessmentEndDate
	  GROUP BY MMSTran.MembershipID



   INSERT INTO #Results
   SELECT #MMSTran.MMSTranID,
          TranItem.TranItemID,
          CASE WHEN IsNull(TranItemRefund.TranItemID,0) <> 0 AND #MMSTran.ClubID = 13 
		       THEN RefundOriginalValRegion.Description
               ELSE ValRegion.Description END Region,
          CASE WHEN IsNull(TranItemRefund.TranItemID,0) <> 0 AND #MMSTran.ClubID = 13 
		       THEN RefundOriginalClub.ClubCode
               ELSE Club.ClubCode END ClubCode,
          CASE WHEN IsNull(TranItemRefund.TranItemID,0) <> 0 AND #MMSTran.ClubID = 13 
		       THEN RefundOriginalClub.ClubName
               ELSE Club.ClubName END ClubName,
          CASE WHEN IsNull(TranItemRefund.TranItemID,0) <> 0 AND #MMSTran.ClubID = 13 
		       THEN RefundOriginalClub.ClubID
               ELSE Club.ClubID END ClubID,
          ValTranType.Description TransactionType,
          Replace(Substring(convert(varchar,#MMSTran.PostDateTime,100),1,6)+', '+Substring(convert(varchar,#MMSTran.PostDateTime,100),8,4),'  ',' ') MMSPostDate,
          Replace(Substring(convert(varchar,DrawerActivity.CloseDateTime,100),1,6)+', '+Substring(convert(varchar,DrawerActivity.CloseDateTime,100),8,4),'  ',' ') MMSDrawerCloseDate,
          NULL CafeCloseDate,
          NULL CafePostDate,
          NULL ECommerceOrderDate,
          NULL ECommerceShipmentDate,
          NULL EDWInsertedDate,
          'MMS' Source,
          'MMS ' + Convert(Varchar,ReportDimProduct.MMSProductID) SourceProductID,
          ReportDimProduct.ProductDescription,
          #MMSPaymentTypes.PaymentTypes,
          Member.MemberID,
          Member.LastName + ', ' + Member.FirstName MemberName,
          ReasonCode.Description TransactionReason,
          TransactionEmployee.EmployeeID TransactionTeamMemberID,
          TransactionEmployee.LastName + ', ' + TransactionEmployee.FirstName TransactionTeamMemberName,
          TransactionEmployeeClub.ClubName TransactionTeamMemberHomeClub,
          PrimaryEmployee.EmployeeID CommissionedTeamMember1ID,
          PrimaryEmployee.LastName + ', ' + PrimaryEmployee.FirstName CommissionedTeamMember1Name,
          PrimaryEmployeeClub.ClubName CommissionedTeamMember1HomeClub,
          SecondaryEmployee.EmployeeID CommissionedTeamMember2ID,
          SecondaryEmployee.LastName + ', ' + SecondaryEmployee.FirstName CommissionedTeamMember2Name,
          SecondaryEmployeeClub.ClubName CommissionedTeamMember2HomeClub,
          TranItem.Quantity SalesQuantity,
          CASE WHEN ISNULL(TranItem.SoldNotServicedFlag,0) = 0 
		       THEN 'N' 
			   ELSE 'Y' END SNSFlag,
          
          (CASE WHEN ValTranType.ValTranTypeID = 5 
		        THEN ISNULL(TranItem.ItemAmount, #MMSTran.TranAmount + #MMSTran.POSAmount)
                ELSE ISNULL(TranItem.ItemAmount, #MMSTran.TranAmount) 
                END + ISNULL(TranItem.ItemDiscountAmount,0)) GrossTransactionAmount,
		  TranItem.ItemDiscountAmount  TotalDiscountAmount,
		  TranItem.ItemSalesTax  SalesTax,
		  (CASE WHEN ValTranType.ValTranTypeID = 5 
		        THEN ISNULL(TranItem.ItemAmount, #MMSTran.TranAmount + #MMSTran.POSAmount)
                ELSE ISNULL(TranItem.ItemAmount,#MMSTran.TranAmount)
                 END)  TotalAmount,
		  #MMSDiscounts.DiscountAmount1  DiscountAmount1,
          #MMSDiscounts.DiscountAmount2  DiscountAmount2,
          #MMSDiscounts.DiscountAmount3  DiscountAmount3,
          #MMSDiscounts.DiscountAmount4  DiscountAmount4,
          #MMSDiscounts.DiscountAmount5  DiscountAmount5,
          #MMSDiscounts.Discount1,
          #MMSDiscounts.Discount2,
          #MMSDiscounts.Discount3,
          #MMSDiscounts.Discount4,
          #MMSDiscounts.Discount5,
          #MMSTran.PostDateTime TransactionDate,
          CASE WHEN IsNull(ValProductSalesChannel.ValProductSalesChannelID,0) <> 0 
		        THEN 'LTF E-Commerce - ' + ValProductSalesChannel.Description
               WHEN #MMSTran.EmployeeID IN (-2,-4,-5) 
			    THEN TransactionEmployee.FirstName + ' ' + TransactionEmployee.LastName
               ELSE 'MMS' END SalesChannel,
		  CASE WHEN TranItem.ItemAmount != 0 
		         THEN SIGN(TranItem.ItemAmount) * TranItem.Quantity
               WHEN TranItem.ItemDiscountAmount != 0 
			     THEN SIGN(TranItem.ItemDiscountAmount) * TranItem.Quantity
               WHEN (#MMSTran.ValTranTypeID != 5 AND #MMSTran.ReverseTranFlag = 1) OR (#MMSTran.ValTranTypeID = 5 AND #MMSTran.ReverseTranFlag = 0) 
			     THEN -1 * TranItem.Quantity
               ELSE TranItem.Quantity 
			     END * ReportDimProduct.CorporateTransferMultiplier  CorporateTransferAmount,
          CASE WHEN IsNull(TranItemRefund.TranItemID,0) <> 0 AND #MMSTran.ClubID = 13 
		       THEN RefundOriginalClub.GLClubID
               ELSE Club.GLClubID END GLClubID,
		  #MMSTran.TransactionComment,
		  #MembershipDues.MembershipDuesAssessed,
		  #MembershipJuniorDues.JuniorDuesAssessed,
		  #MMSTran.MemberRelationsAdjustmentCategory
     FROM #MMSTran
     LEFT JOIN vTranItem TranItem
       ON #MMSTran.MMSTranID = TranItem.MMSTranID
     LEFT JOIN vReportDimProduct ReportDimProduct
       ON TranItem.ProductID = ReportDimProduct.MMSProductID
     LEFT JOIN (SELECT PrimarySaleCommission.TranItemID, 
                       MAX(PrimaryEmployee.EmployeeID) PrimaryEmployeeID,
                       MAX(SecondaryEmployee.EmployeeID) SecondaryEmployeeID
                   FROM vSaleCommission PrimarySaleCommission
                   JOIN vEmployee PrimaryEmployee
                     ON PrimarySaleCommission.EmployeeID = PrimaryEmployee.EmployeeID
                   LEFT JOIN vSaleCommission SecondarySaleCommission
                     ON PrimarySaleCommission.TranItemID = SecondarySaleCommission.TranItemID
                    AND PrimarySaleCommission.EmployeeID > SecondarySaleCommission.EmployeeID
                   LEFT JOIN vEmployee SecondaryEmployee
                     ON SecondarySaleCommission.EmployeeID = SecondaryEmployee.EmployeeID
                  GROUP BY PrimarySaleCommission.TranItemID) CommissionedEmployees
       ON TranItem.TranItemID = CommissionedEmployees.TranItemID
    LEFT JOIN vEmployee PrimaryEmployee
      ON CommissionedEmployees.PrimaryEmployeeID = PrimaryEmployee.EmployeeID
    LEFT JOIN vClub PrimaryEmployeeClub
      ON PrimaryEmployee.ClubID = PrimaryEmployeeClub.ClubID
    LEFT JOIN vEmployee SecondaryEmployee
      ON CommissionedEmployees.SecondaryEmployeeID = SecondaryEmployee.EmployeeID
    LEFT JOIN vClub SecondaryEmployeeClub
      ON SecondaryEmployee.ClubID = SecondaryEmployeeClub.ClubID
    JOIN vClub Club
      ON #MMSTran.ClubID = Club.ClubID
    JOIN vValRegion ValRegion
      ON Club.ValRegionID = ValRegion.ValRegionID
    JOIN vDrawerActivity DrawerActivity
      ON #MMSTran.DrawerActivityID = DrawerActivity.DrawerActivityID
    JOIN vMember Member
      ON #MMSTran.MemberID = Member.MemberID
    JOIN vReasonCode ReasonCode
      ON #MMSTran.ReasonCodeID = ReasonCode.ReasonCodeID
    JOIN vEmployee TransactionEmployee
      ON #MMSTran.EmployeeID = TransactionEmployee.EmployeeID
    JOIN vClub TransactionEmployeeClub
      ON TransactionEmployee.ClubID = TransactionEmployeeClub.ClubID
    JOIN vValTranType ValTranType
      ON #MMSTran.ValTranTypeID = ValTranType.ValTranTypeID
    LEFT JOIN #MMSDiscounts
      ON TranItem.TranItemID = #MMSDiscounts.TranItemID
    LEFT JOIN #MMSPaymentTypes
      ON #MMSTran.MMSTranID = #MMSPaymentTypes.MMSTranID
    JOIN vValCurrencyCode ValCurrencyCode
      ON #MMSTran.ValCurrencyCodeID = ValCurrencyCode.ValCurrencyCodeID
    LEFT JOIN vWebOrderMMSTran WebOrderMMSTran
      ON #MMSTran.MMSTranID = WebOrderMMSTran.MMSTranID
    LEFT JOIN vWebOrder WebOrder
      ON WebOrderMMSTran.WebOrderID = WebOrder.WebOrderID
    LEFT JOIN vValProductSalesChannel ValProductSalesChannel
      ON WebOrder.ValProductSalesChannelID = ValProductSalesChannel.ValProductSalesChannelID
--Automated refund handling
    LEFT JOIN vTranItemRefund TranItemRefund
      ON TranItem.TranItemID = TranItemRefund.TranItemID
    LEFT JOIN vTranItem RefundOriginalTranItem
      ON TranItemRefund.OriginalTranItemID = RefundOriginalTranItem.TranItemID
    LEFT JOIN vMMSTran RefundOriginalMMSTran
      ON RefundOriginalTranItem.MMSTranID = RefundOriginalMMSTran.MMSTranID
    LEFT JOIN vClub RefundOriginalClub
      ON RefundOriginalMMSTran.ClubID = RefundOriginalClub.ClubID
    LEFT JOIN vValRegion RefundOriginalValRegion
      ON RefundOriginalClub.ValRegionID = RefundOriginalValRegion.ValRegionID
--Membership filter
    JOIN vMembership Membership
      ON #MMSTran.MembershipID = Membership.MembershipID
    LEFT JOIN vMembershipTypeAttribute FounderMembershipTypeAttribute
      ON Membership.MembershipTypeID = FounderMembershipTypeAttribute.MembershipTypeID
     AND FounderMembershipTypeAttribute.ValMembershipTypeAttributeID = 32 --Founders
    LEFT JOIN vMembershipTypeAttribute EmployeeMembershipTypeAttribute
      ON Membership.MembershipTypeID = EmployeeMembershipTypeAttribute.MembershipTypeID
     AND EmployeeMembershipTypeAttribute.ValMembershipTypeAttributeID = 4 --Employee
    LEFT JOIN #CorporateMemberships
      ON Membership.MembershipID = #CorporateMemberships.MembershipID
	LEFT JOIN #MembershipDues
	  ON #MMSTran.MembershipID = #MembershipDues.MembershipID
	LEFT JOIN #MembershipJuniorDues
	  ON #MMSTran.MembershipID = #MembershipJuniorDues.MembershipID
   WHERE (@MembershipFilter = 'All Memberships' 
          OR (@MembershipFilter = 'All Memberships - exclude Founders' AND IsNull(FounderMembershipTypeAttribute.MembershipTypeID,0) = 0)
          OR (@MembershipFilter = 'Employee Memberships' AND IsNull(EmployeeMembershipTypeAttribute.MembershipTypeID,0) <> 0)
          OR (@MembershipFilter = 'Corporate Memberships' AND IsNull(#CorporateMemberships.MembershipID,0) <> 0))

DROP TABLE #MMSDiscounts
DROP TABLE #MMSPaymentTypes
DROP TABLE #MMSPayments
DROP TABLE #MMSTran
DROP TABLE #TodayMMSTran
-----DROP TABLE #MMSClubIDList
DROP TABLE #SalesSourceList
DROP TABLE #ValTranTypeIDList
----DROP TABLE #Results
DROP TABLE #ReasonCodeIDList
DROP TABLE #TransactionMembershipIDs
DROP TABLE #MembershipDues
DROP TABLE #MembershipJuniorDues
DROP TABLE #CorporateMemberships

END

SELECT Cast(Region as Varchar(50)) Region,
       Cast(ClubCode as Varchar(18)) ClubCode,
       Cast(ClubName as Varchar(50)) ClubName,
       Cast(TransactionType as Varchar(10)) TransactionType,
       Cast(MMSPostDate as Varchar(12)) MMSPostDate,
       Cast(MMSDrawerCloseDate as Varchar(12)) MMSDrawerCloseDate,
       Cast(CafeCloseDate as Varchar(12)) CafeCloseDate,
       Cast(CafePostDate as Varchar(12)) CafePostDate,
       Cast(ECommerceOrderDate as Varchar(12)) ECommerceOrderDate,
       Cast(ECommerceShipmentDate as Varchar(12)) ECommerceShipmentDate,
       Cast(EDWInsertedDate as Varchar(12)) EDWInsertedDate,
       Cast(Source as Varchar(10)) Source,
       Cast(SourceProductID as Varchar(61)) SourceProductID,
       Cast(ProductDescription as Varchar(50)) ProductDescription,
       Cast(PaymentTypes as Varchar(4000)) PaymentTypes,
       MemberID,
       Cast(MemberName as Varchar(132)) MemberName,
       Cast(TransactionReason as Varchar(50)) TransactionReason,
       TransactionTeamMemberID,
       Cast(TransactionTeamMemberName as Varchar(102)) TransactionTeamMemberName,
       Cast(TransactionTeamMemberHomeClub as Varchar(50)) TransactionTeamMemberHomeClub,
       CommissionedTeamMember1ID,
       Cast(CommissionedTeamMember1Name as Varchar(102)) CommissionedTeamMember1Name,
       Cast(CommissionedTeamMember1HomeClub as Varchar(50)) CommissionedTeamMember1HomeClub,
       CommissionedTeamMember2ID,
       Cast(CommissionedTeamMember2Name as Varchar(102)) CommissionedTeamMember2Name,
       Cast(CommissionedTeamMember2HomeClub as Varchar(50)) CommissionedTeamMember2HomeClub,
       SalesQuantity,
       SNSFlag,
       Cast(GrossTransactionAmount as Decimal(12,2)) GrossTransactionAmount,
       Cast(TotalDiscountAmount as Decimal(12,2)) TotalDiscountAmount,
       Cast(SalesTax as Decimal(12,2)) SalesTax,
       Cast(TotalAmount as Decimal(12,2)) TotalAmount,
       Cast(DiscountAmount1 as Decimal(12,2)) DiscountAmount1,
       Cast(DiscountAmount2 as Decimal(12,2)) DiscountAmount2,
       Cast(DiscountAmount3 as Decimal(12,2)) DiscountAmount3,
       Cast(DiscountAmount4 as Decimal(12,2)) DiscountAmount4,
       Cast(DiscountAmount5 as Decimal(12,2)) DiscountAmount5,
       Cast(Discount1 as Varchar(50)) Discount1,
       Cast(Discount2 as Varchar(50)) Discount2,
       Cast(Discount3 as Varchar(50)) Discount3,
       Cast(Discount4 as Varchar(50)) Discount4,
       Cast(Discount5 as Varchar(50)) Discount5,
       Cast(@CurrencyCode as Varchar(15)) ReportingCurrencyCode,
       Cast(@ReportRunDateTime as Varchar(21)) ReportRunDateTime,
       TransactionDate,
       Cast(@HeaderDateRange as Varchar(51)) HeaderDateRange,
       Cast(@SalesSourceCommaList as Varchar(4000)) HeaderSourceList,
       Cast(@TransactionTypeCommaList as Varchar(4000)) HeaderTransactionTypeList,
       Cast(@HeaderTransactionReason as Varchar(102)) HeaderTransactionReason,
       1 RecordCount,
       Cast('' as Varchar(71)) HeaderEmptyResult,
       CAST(SalesChannel as Varchar(50)) SalesChannel,
       CAST(TotalAmount + ISNULL(SalesTax,0) as Decimal(12,2)) TotalAmountAfterTax,
       CAST(CorporateTransferAmount as Decimal(12,2)) CorporateTransferAmount,
       CAST(NULL AS Varchar(255)) ECommerceShipmentNumber,
       CAST(NULL AS INT) ECommerceOrderNumber,
       CAST(NULL AS  CHAR(1)) ECommerceAutoShipFlag,
       CAST(NULL AS Varchar(255)) ECommerceOrderEntryTrackingNumber,
       CAST(NULL AS Decimal(12,2)) ECommerceProductCost,
       CAST(NULL AS INT)  ECommerceShipmentLineNumber,
       CAST(NULL AS Decimal(12,2))ECommerceShippingAndHandlingAmount,
       CAST(GLClubID AS INT)  GLClubID,
	   CAST(TransactionComment AS Varchar(255)) TransactionComment,
	   CAST(MembershipDuesAssessed AS Decimal(12,2)) MembershipDuesAssessed,
	   CAST(JuniorDuesAssessed AS Decimal(12,2)) JuniorDuesAssessed,
	   CAST(MemberRelationsAdjustmentCategory as Varchar(50)) MemberRelationsAdjustmentCategory  
  FROM #Results
  JOIN #MMSClubIDList
    ON #Results.ClubID = #MMSClubIDList.MMSClubID
 WHERE (SELECT COUNT(*) FROM #Results) <> 0
UNION ALL
SELECT Cast(NULL as Varchar(50)) Region,
       Cast(NULL as Varchar(18)) ClubCode,
       Cast(NULL as Varchar(50)) ClubName,
       Cast(NULL as Varchar(10)) TransactionType,
       Cast(NULL as Varchar(12)) MMSPostDate,
       Cast(NULL as Varchar(12)) MMSDrawerCloseDate,
       Cast(NULL as Varchar(12)) CafeCloseDate,
       Cast(NULL as Varchar(12)) CafePostDate,
       Cast(NULL as Varchar(12)) ECommerceOrderDate,
       Cast(NULL as Varchar(12)) ECommerceShipmentDate,
       Cast(NULL as Varchar(12)) EDWInsertedDate,
       Cast(NULL as Varchar(10)) Source,
       Cast(NULL as Varchar(61)) SourceProductID,
       Cast(NULL as Varchar(50)) ProductDescription,
       Cast(NULL as Varchar(4000)) PaymentTypes,
       NULL MemberID,
       Cast(NULL as Varchar(132)) MemberName,
       Cast(NULL as Varchar(50)) TransactionReason,
       NULL TransactionTeamMemberID,
       Cast(NULL as Varchar(102)) TransactionTeamMemberName,
       Cast(NULL as Varchar(50)) TransactionTeamMemberHomeClub,
       NULL CommissionedTeamMember1ID,
       Cast(NULL as Varchar(102)) CommissionedTeamMember1Name,
       Cast(NULL as Varchar(50)) CommissionedTeamMember1HomeClub,
       NULL CommissionedTeamMember2ID,
       Cast(NULL as Varchar(102)) CommissionedTeamMember2Name,
       Cast(NULL as Varchar(50)) CommissionedTeamMember2HomeClub,
       NULL SalesQuantity,
       Cast(NULL as Char(1)) SNSFlag,
       Cast(NULL as Decimal(12,2)) GrossTransactionAmount,
       Cast(NULL as Decimal(12,2)) TotalDiscountAmount,
       Cast(NULL as Decimal(12,2)) SalesTax,
       Cast(NULL as Decimal(12,2)) TotalAmount,
       Cast(NULL as Decimal(12,2)) DiscountAmount1,
       Cast(NULL as Decimal(12,2)) DiscountAmount2,
       Cast(NULL as Decimal(12,2)) DiscountAmount3,
       Cast(NULL as Decimal(12,2)) DiscountAmount4,
       Cast(NULL as Decimal(12,2)) DiscountAmount5,
       Cast(NULL as Varchar(50)) Discount1,
       Cast(NULL as Varchar(50)) Discount2,
       Cast(NULL as Varchar(50)) Discount3,
       Cast(NULL as Varchar(50)) Discount4,
       Cast(NULL as Varchar(50)) Discount5,
       Cast(@CurrencyCode as Varchar(15)) ReportingCurrencyCode,
       Cast(@ReportRunDateTime as Varchar(21)) ReportRunDateTime,
       Cast(NULL as DATETIME) TransactionDate,
       Cast(@HeaderDateRange as Varchar(51)) HeaderDateRange,
       Cast(@SalesSourceCommaList as Varchar(4000)) HeaderSourceList,
       Cast(@TransactionTypeCommaList as Varchar(4000)) HeaderTransactionTypeList,
       Cast(@HeaderTransactionReason as Varchar(102)) HeaderTransactionReason,
       0 RecordCount,
       'There is no data available for the selected parameters.  Please re-try.' HeaderEmptyResult,
       CAST(NULL as Varchar(50)) SalesChannel,
       CAST(NULL as Decimal(12,2)) TotalAmountAfterTax,
       CAST(NULL as Decimal(12,2)) CorporateTransferAmount,
       CAST(NULL AS Varchar(255)) ECommerceShipmentNumber,
       CAST(NULL AS INT) ECommerceOrderNumber,
       CAST(NULL AS  CHAR(1)) ECommerceAutoShipFlag,
       CAST(NULL AS Varchar(255)) ECommerceOrderEntryTrackingNumber,
       CAST(NULL AS Decimal(12,2)) ECommerceProductCost,
       CAST(NULL AS INT)  ECommerceShipmentLineNumber,
       CAST(NULL AS Decimal(12,2))ECommerceShippingAndHandlingAmount,
       CAST(NULL AS INT)  GLClubID,
	   CAST(NULL AS Varchar(255)) TransactionComment,
	   CAST(NULL AS Decimal(12,2)) MembershipDuesAssessed,
	   CAST(NULL AS Decimal(12,2)) JuniorDuesAssessed,
	   CAST(NULL AS Varchar(50)) MemberRelationsAdjustmentCategory   
WHERE (SELECT COUNT(*) FROM #Results) = 0






DROP TABLE #MMSClubIDList
DROP TABLE #Results




END



