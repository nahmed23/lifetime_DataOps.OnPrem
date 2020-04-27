


CREATE PROC [dbo].[procCognos_RealTimeClubDetailSalesByReportingDepartment_Today_DrillThrough] (
     @DepartmentMinDimReportingHierarchyKeyList Varchar(8000),
     @MMSClubID INT,
	 @DivisionList Varchar(8000),
	 @SubdivisionList Varchar(8000)
)

AS
BEGIN 
SET XACT_ABORT ON
SET NOCOUNT ON

IF 1=0 BEGIN
       SET FMTONLY OFF
     END

----- Execution Sample
----- exec procCognos_RealTimeClubDetailSalesByReportingDepartment_Today_DrillThrough '-1','238','Personal Training', 'All Subdivisions'
----- 

DECLARE @StartDate DATETIME
SET @StartDate = CONVERT(DATETIME,CONVERT(VARCHAR,GETDATE(),101),101) -- Today

DECLARE @EndDate DATETIME
SET @EndDate = CONVERT(DATETIME,CONVERT(VARCHAR,GETDATE(),101),101) -- Today

DECLARE @HeaderDateRange Varchar(110)
DECLARE @ReportRunDateTime VARCHAR(21)
DECLARE @IncludeTodaysTransactionsFlag CHAR(1)

SET @IncludeTodaysTransactionsFlag = CASE WHEN @StartDate >= CONVERT(Datetime,CONVERT(Varchar,GetDate(),101),101) 
                                               OR @EndDate >= CONVERT(Datetime,CONVERT(Varchar,GetDate(),101),101)
                                               THEN 'Y'
                                          ELSE 'N' END
SET @HeaderDateRange = Replace(Substring(convert(varchar, @StartDate, 100),1,6)+', '+Substring(convert(varchar, @StartDate, 100),8,4),'  ',' ')
SET @ReportRunDateTime = Replace(Substring(convert(varchar, GetDate(), 100),1,6)+', '+Substring(convert(varchar, GetDate(), 100),8,10)+' '+Substring(convert(varchar,GetDate(), 100),18,2),'  ',' ')

SELECT DISTINCT ReportDimReportingHierarchy.DimReportingHierarchyKey,
                ReportDimReportingHierarchy.DivisionName,
                ReportDimReportingHierarchy.SubdivisionName,
                ReportDimReportingHierarchy.DepartmentName,
                ReportDimReportingHierarchy.ProductGroupName,
                ReportDimReportingHierarchy.ProductGroupSortOrder,
                ReportDimReportingHierarchy.RegionType
  INTO #DimReportingHierarchy
  FROM vReportDimReportingHierarchy BridgeTable
  JOIN fnParsePipeList(@DivisionList) DivisionList
    ON BridgeTable.DivisionName = DivisionList.Item
    OR DivisionList.Item = 'All Divisions'
  JOIN fnParsePipeList(@SubdivisionList) SubdivisionList
    ON BridgeTable.SubdivisionName = SubdivisionList.Item
    OR SubdivisionList.Item = 'All Subdivisions'
  JOIN fnParsePipeList(@DepartmentMinDimReportingHierarchyKeyList) KeyList
    ON Cast(BridgeTable.DimReportingHierarchyKey as Varchar) = KeyList.Item
    OR KeyList.Item like '%-1%' 
  JOIN vReportDimReportingHierarchy ReportDimReportingHierarchy
    ON BridgeTable.DivisionName = ReportDimReportingHierarchy.DivisionName
   AND BridgeTable.SubdivisionName = ReportDimReportingHierarchy.SubdivisionName
   AND BridgeTable.DepartmentName = ReportDimReportingHierarchy.DepartmentName

DECLARE @HeaderDivisionList VARCHAR(8000),
        @HeaderSubdivisionList VARCHAR(8000),
        @RevenueReportingDepartmentNameCommaList VARCHAR(8000)

SELECT @HeaderDivisionList = STUFF((SELECT DISTINCT ','+DivisionName
                                      FROM #DimReportingHierarchy
                                       FOR XML PATH('')),1,1,''),
       @HeaderSubdivisionList = STUFF((SELECT DISTINCT ','+SubdivisionName
                                         FROM #DimReportingHierarchy
                                          FOR XML PATH('')),1,1,''),
       @RevenueReportingDepartmentNameCommaList = STUFF((SELECT DISTINCT ','+DepartmentName
                                                           FROM #DimReportingHierarchy
                                                            FOR XML PATH('')),1,1,'')

SELECT MMSTranID,
       ClubID,
       PostDateTime,
       ReasonCodeID,
       MembershipID,
       ValTranTypeID,
       ReverseTranFlag,
       MemberID,
       EmployeeID,
       ValCurrencyCodeID
  INTO #TodayMMSTran
  FROM vMMSTranNonArchive MMSTran
 WHERE MMSTran.PostDateTime >= Convert(Datetime,Convert(Varchar,GetDate(),101),101)
   AND MMSTran.TranVoidedID is NULL
   AND MMSTran.ValTranTypeID in (1,3,4,5)
   AND @IncludeTodaysTransactionsFlag = 'Y'

/**************** Start Discounts ****************/
CREATE TABLE #TMPDiscount (
       TranItemID INT,
       ItemAmount MONEY,
       TotalDiscountAmount MONEY,
       ReceiptText1 VARCHAR(50),
       AppliedDiscountAmount1 MONEY,
       ReceiptText2 VARCHAR(50),
       AppliedDiscountAmount2 MONEY,
       ReceiptText3 VARCHAR(50),
       AppliedDiscountAmount3 MONEY,
       ReceiptText4 VARCHAR(50),
       AppliedDiscountAmount4 MONEY,
       ReceiptText5 VARCHAR(50),
       AppliedDiscountAmount5 MONEY)

DECLARE @TranItemID INT,
        @ItemAmount MONEY,
        @TotalDiscountAmount MONEY,
        @ReceiptText VARCHAR(50),
        @AppliedDiscountAmount MONEY,
        @HOLDTranItemID INT,
        @Counter INT

SET @HOLDTranItemID = -1
SET @Counter = 1

DECLARE Discount_Cursor CURSOR LOCAL READ_ONLY FOR
SELECT TI.TranItemID, TI.ItemAmount, TI.ItemDiscountAmount as TotalDiscountAmount,SP.ReceiptText,TID.AppliedDiscountAmount
  FROM #TodayMMSTran MMST
  JOIN vTranItem TI
    ON MMST.MMSTranID = TI.MMSTranID
  JOIN vValTranType VTT
    ON VTT.ValTranTypeID = MMST.ValTranTypeID
  JOIN vTranItemDiscount TID
    ON TID.TranItemID = TI.TranItemID
  JOIN vPricingDiscount PD
    ON PD.PricingDiscountID = TID.PricingDiscountID
  JOIN vSalesPromotion SP
    ON PD.SalesPromotionID = SP.SalesPromotionID
 ORDER BY TI.TranItemID, PD.SalesPromotionID

OPEN Discount_Cursor
FETCH NEXT FROM Discount_Cursor INTO @TranItemID,@ItemAmount,@TotalDiscountAmount,@ReceiptText,@AppliedDiscountAmount
WHILE (@@FETCH_STATUS = 0)
    BEGIN

        IF @TranItemID != @HOLDTranItemID
            BEGIN
                INSERT INTO #TMPDiscount
                   (TranItemID, ItemAmount, TotalDiscountAmount, ReceiptText1, AppliedDiscountAmount1)
                VALUES (@TranItemID,@ItemAmount,@TotalDiscountAmount,@ReceiptText,@AppliedDiscountAmount)
                SET @HOLDTranItemID = @TranItemID
                SET @Counter = 1
            END
        ELSE
            BEGIN
                SET @Counter = @Counter + 1
                IF @Counter = 2
                    BEGIN
                        UPDATE #TMPDiscount SET ReceiptText2 = @ReceiptText, AppliedDiscountAmount2 = @AppliedDiscountAmount
                         WHERE TranItemID = @TranItemID
                    END
                IF @Counter = 3
                    BEGIN
                        UPDATE #TMPDiscount SET ReceiptText3 = @ReceiptText, AppliedDiscountAmount3 = @AppliedDiscountAmount
                          WHERE TranItemID = @TranItemID
                    END
                IF @Counter = 4
                    BEGIN
                        UPDATE #TMPDiscount SET ReceiptText4 = @ReceiptText, AppliedDiscountAmount4 = @AppliedDiscountAmount
                          WHERE TranItemID = @TranItemID
                    END
                IF @Counter = 5
                    BEGIN
                        UPDATE #TMPDiscount SET ReceiptText5 = @ReceiptText, AppliedDiscountAmount5 = @AppliedDiscountAmount
                         WHERE TranItemID = @TranItemID
                    END
                SET @HOLDTranItemID = @TranItemID
            END

    FETCH NEXT FROM Discount_Cursor INTO @TranItemID,@ItemAmount,@TotalDiscountAmount,@ReceiptText,@AppliedDiscountAmount
    END

CLOSE Discount_Cursor
DEALLOCATE Discount_Cursor 
/**************** End Discounts ****************/

SELECT MMSTranRefund.MMSTranRefundID,
       MMSTran.MMSTranID RefundMMSTranID,
       MMSTran.ReasonCodeID RefundReasonCodeID,
       Membership.ClubID MembershipClubID
  INTO #RefundTranIDs
  FROM vMMSTranRefund MMSTranRefund
  JOIN #TodayMMSTran MMSTran 
    ON MMSTranRefund.MMSTranID = MMSTran.MMSTranID
  JOIN vMembership Membership 
    ON Membership.MembershipID = MMSTran.MembershipID

SELECT #RefundTranIDs.RefundMMSTranID,
       CASE WHEN #RefundTranIDs.RefundReasonCodeID = 108 OR MMSTran.ClubID in (13)
                 THEN #RefundTranIDs.MembershipClubID
            ELSE MMSTran.ClubID END AS PostingMMSClubID
  INTO #ReportRefunds
  FROM #RefundTranIDs
  JOIN vMMSTranRefundMMSTran MMSTranRefundMMSTran 
    ON MMSTranRefundMMSTran.MMSTranRefundID = #RefundTranIDs.MMSTranRefundID
  JOIN vMMSTran MMSTran 
    ON MMSTran.MMSTranID = MMSTranRefundMMSTran.OriginalMMSTranID
 GROUP BY #RefundTranIDs.RefundMMSTranID,
          CASE WHEN #RefundTranIDs.RefundReasonCodeID = 108 OR MMSTran.ClubID in (13)
                    THEN #RefundTranIDs.MembershipClubID
               ELSE MMSTran.ClubID END 

--Non-Corporate internal transactions
SELECT CASE WHEN MMSTran.ClubID = 9999 THEN TranItem.ClubID     
            WHEN MMSTran.ClubID = 13 THEN Membership.ClubID                           
            ELSE MMSTran.ClubID END AS MMSClubID,
       Replace(Substring(convert(varchar,MMSTran.PostDateTime,100),1,6)+', '+Substring(convert(varchar,MMSTran.PostDateTime,100),8,10)+' '+Substring(convert(varchar,MMSTran.PostDateTime,100),18,2),'  ',' ') SaleDateAndTime,
       Replace(Substring(convert(varchar,MMSTran.PostDateTime,100),1,6)+', '+Substring(convert(varchar,MMSTran.PostDateTime,100),8,4),'  ',' ') PostedDate,
       'MMS' SalesSource,
       CONVERT(VARCHAR(50),ReportDimProduct.MMSProductID) SourceProductID,
       ReportDimProduct.ProductDescription,
       #DimReportingHierarchy.DepartmentName RevenueReportingDepartmentName,
       #DimReportingHierarchy.ProductGroupName RevenueProductGroup,
       PrimaryEmployee.EmployeeID PrimarySellingTeamMemberID,
       PrimaryEmployee.LastName + ', ' + PrimaryEmployee.FirstName PrimarySellingTeamMember,
       CASE WHEN SecondaryEmployee.EmployeeID = PrimaryEmployee.EmployeeID
                 THEN NULL
            ELSE SecondaryEmployee.EmployeeID END SecondarySellingTeamMemberID,
       CASE WHEN SecondaryEmployee.EmployeeID = PrimaryEmployee.EmployeeID
                 THEN 'None Designated' 
            ELSE SecondaryEmployee.LastName + ', ' + SecondaryEmployee.FirstName END SecondarySellingTeamMember,
       MMSTran.MembershipID,
       MembershipProduct.Description MembershipTypeDescription,
       Member.MemberID,
       Member.LastName + ', ' + Member.FirstName MemberName,
       NULL RevenueQuantity,
       NULL RevenueAmount,
       TranItem.Quantity SaleQuantity,
       TranItem.ItemAmount SaleAmount,       
       #TMPDiscount.TotalDiscountAmount TotalDiscountAmount,
       #TMPDiscount.AppliedDiscountAmount1 DiscountAmount1,
       #TMPDiscount.AppliedDiscountAmount2 DiscountAmount2,
       #TMPDiscount.AppliedDiscountAmount3 DiscountAmount3,
       #TMPDiscount.AppliedDiscountAmount4 DiscountAmount4,
       #TMPDiscount.AppliedDiscountAmount5 DiscountAmount5,
       #TMPDiscount.ReceiptText1 Discount1,
       #TMPDiscount.ReceiptText2 Discount2,
       #TMPDiscount.ReceiptText3 Discount3,
       #TMPDiscount.ReceiptText4 Discount4,
       #TMPDiscount.ReceiptText5 Discount5,
       Cast(Convert(Varchar,MMSTran.PostDateTime,112) as INT) SaleDimDateKey,
       Cast('1'+Replace(Convert(Varchar(6),MMSTran.PostDateTime,108),':','') as INT) SaleDimTimeKey,
       Member.FirstName MemberFirstName,
       Member.LastName MemberLastName,
       OriginalCurrencyCode.CurrencyCode CurrencyCode,
       Year(MMSTran.PostDateTime) TranYear,
       CASE WHEN IsNull(TranItem.SoldNotServicedFlag,0) = 1 THEN 'Y' ELSE 'N' END SoldNotServicedFlag,
       MMSTran.MMSTranID,
       MMSTran.EmployeeID TransactionEmployeeID,
       CASE WHEN TranItem.ItemAmount != 0 THEN SIGN(TranItem.ItemAmount)
            WHEN TranItem.ItemDiscountAmount != 0 THEN SIGN(TranItem.ItemDiscountAmount) * TranItem.Quantity
            WHEN (MMSTran.ValTranTypeID != 5 AND MMSTran.ReverseTranFlag = 1)
                 OR (MMSTran.ValTranTypeID = 5 AND MMSTran.ReverseTranFlag = 0) THEN -1 * TranItem.Quantity
            ELSE TranItem.Quantity END * ReportDimProduct.CorporateTransferMultiplier CorporateTransferAmount,
       #DimReportingHierarchy.DivisionName,
       #DimReportingHierarchy.SubdivisionName
  INTO #ReportingData
  FROM #TodayMMSTran MMSTran
  JOIN vTranItem TranItem 
    ON MMSTran.MMSTranID = TranItem.MMSTranID
  LEFT JOIN (SELECT TranItemID, Min(EmployeeID) PrimarySalesEmployeeID, MAX(EmployeeID) SecondarySalesEmployeeID
               FROM vSaleCommission SaleCommission
           GROUP BY TranItemID) Employees
    ON TranItem.TranItemID = Employees.TranItemID
  JOIN vReportDimProduct ReportDimProduct
    ON TranItem.ProductID = ReportDimProduct.MMSProductID
  JOIN #DimReportingHierarchy
    ON ReportDimProduct.DimReportingHierarchyKey = #DimReportingHierarchy.DimReportingHierarchyKey
  LEFT JOIN vMMSTranRefund MMSTranRefund 
    ON MMSTran.MMSTranID = MMSTranRefund.MMSTranID
  LEFT JOIN #TMPDiscount 
    ON TranItem.TranItemID =  #TMPDiscount.TranItemID
  LEFT JOIN vEmployee PrimaryEmployee 
    ON Employees.PrimarySalesEmployeeID = PrimaryEmployee.EmployeeID
  LEFT JOIN vEmployee SecondaryEmployee 
    ON Employees.SecondarySalesEmployeeID = SecondaryEmployee.EmployeeID
  JOIN vMembership Membership 
    ON MMSTran.MembershipID = Membership.MembershipID
  JOIN vProduct MembershipProduct 
    ON Membership.MembershipTypeID = MembershipProduct.ProductID
  JOIN vMember Member 
    ON MMSTran.MemberID = Member.MemberID
  JOIN vValCurrencyCode OriginalCurrencyCode 
    ON ISNULL(MMSTran.ValCurrencyCodeID,1) = OriginalCurrencyCode.ValCurrencyCodeID
 WHERE MMSTranRefund.MMSTranRefundID is NULL
   AND CASE WHEN MMSTran.ClubID = 9999 THEN TranItem.ClubID     
            WHEN MMSTran.ClubID = 13 THEN Membership.ClubID                           
            ELSE MMSTran.ClubID END = @MMSClubID

UNION ALL

--Automated Refunds
SELECT CASE WHEN #ReportRefunds.PostingMMSClubID = 9999 THEN TranItem.ClubID
            ELSE #ReportRefunds.PostingMMSClubID END MMSClubID,
       Replace(Substring(convert(varchar,MMSTran.PostDateTime,100),1,6)+', '+Substring(convert(varchar,MMSTran.PostDateTime,100),8,10)+' '+Substring(convert(varchar,MMSTran.PostDateTime,100),18,2),'  ',' ') SaleDateAndTime,
       Replace(Substring(convert(varchar,MMSTran.PostDateTime,100),1,6)+', '+Substring(convert(varchar,MMSTran.PostDateTime,100),8,4),'  ',' ') PostedDate,
       'MMS' SalesSource,
       CONVERT(VARCHAR(50),ReportDimProduct.MMSProductID) SourceProductID,
       ReportDimProduct.ProductDescription,
       #DimReportingHierarchy.DepartmentName RevenueReportingDepartmentName,
       #DimReportingHierarchy.ProductGroupName RevenueProductGroup,
       PrimaryEmployee.EmployeeID PrimarySellingTeamMemberID,
       PrimaryEmployee.LastName + ', ' + PrimaryEmployee.FirstName PrimarySellingTeamMember,
       CASE WHEN SecondaryEmployee.EmployeeID = PrimaryEmployee.EmployeeID
                 THEN NULL
            ELSE SecondaryEmployee.EmployeeID END SecondarySellingTeamMemberID,
       CASE WHEN SecondaryEmployee.EmployeeID = PrimaryEmployee.EmployeeID
                 THEN 'None Designated' 
            ELSE SecondaryEmployee.LastName + ', ' + SecondaryEmployee.FirstName END SecondarySellingTeamMember,
       MMSTran.MembershipID,
       MembershipProduct.Description MembershipTypeDescription,
       Member.MemberID,
       Member.LastName + ', ' + Member.FirstName MemberName,
       NULL RevenueQuantity,
       NULL RevenueAmount,
       TranItem.Quantity SaleQuantity,
       TranItem.ItemAmount SaleAmount,       
       #TMPDiscount.TotalDiscountAmount TotalDiscountAmount,
       #TMPDiscount.AppliedDiscountAmount1 DiscountAmount1,
       #TMPDiscount.AppliedDiscountAmount2 DiscountAmount2,
       #TMPDiscount.AppliedDiscountAmount3 DiscountAmount3,
       #TMPDiscount.AppliedDiscountAmount4 DiscountAmount4,
       #TMPDiscount.AppliedDiscountAmount5 DiscountAmount5,
       #TMPDiscount.ReceiptText1 Discount1,
       #TMPDiscount.ReceiptText2 Discount2,
       #TMPDiscount.ReceiptText3 Discount3,
       #TMPDiscount.ReceiptText4 Discount4,
       #TMPDiscount.ReceiptText5 Discount5,
       Cast(Convert(Varchar,MMSTran.PostDateTime,112) as INT) SaleDimDateKey,
       Cast('1'+Replace(Convert(Varchar(6),MMSTran.PostDateTime,108),':','') as INT) SaleDimTimeKey,
       Member.FirstName MemberFirstName,
       Member.LastName MemberLastName,
       OriginalCurrencyCode.CurrencyCode CurrencyCode,
       Year(MMSTran.PostDateTime) TranYear,
       CASE WHEN IsNull(TranItem.SoldNotServicedFlag,0) = 1 THEN 'Y' ELSE 'N' END SoldNotServicedFlag,
       MMSTran.MMSTranID,
       MMSTran.EmployeeID TransactionEmployeeID,
       CASE WHEN TranItem.ItemAmount != 0 THEN SIGN(TranItem.ItemAmount)
            WHEN TranItem.ItemDiscountAmount != 0 THEN SIGN(TranItem.ItemDiscountAmount) * TranItem.Quantity
            WHEN (MMSTran.ValTranTypeID != 5 AND MMSTran.ReverseTranFlag = 1)
                 OR (MMSTran.ValTranTypeID = 5 AND MMSTran.ReverseTranFlag = 0) THEN -1 * TranItem.Quantity
            ELSE TranItem.Quantity END * ReportDimProduct.CorporateTransferMultiplier CorporateTransferAmount,
       #DimReportingHierarchy.DivisionName,
       #DimReportingHierarchy.SubdivisionName
  FROM #TodayMMSTran MMSTran
  JOIN #ReportRefunds
    ON #ReportRefunds.RefundMMSTranID = MMSTran.MMSTranID
  JOIN vTranItem TranItem
    ON MMSTran.MMSTranID = TranItem.MMSTranID
  LEFT JOIN (SELECT TranItemID, Min(EmployeeID) PrimarySalesEmployeeID, MAX(EmployeeID) SecondarySalesEmployeeID
               FROM vSaleCommission SaleCommission
           GROUP BY TranItemID) Employees
    ON TranItem.TranItemID = Employees.TranItemID
  JOIN vReportDimProduct ReportDimProduct
    ON TranItem.ProductID = ReportDimProduct.MMSProductID
  JOIN #DimReportingHierarchy
    ON ReportDimProduct.DimReportingHierarchyKey = #DimReportingHierarchy.DimReportingHierarchyKey
  LEFT JOIN #TMPDiscount 
    ON TranItem.TranItemID =  #TMPDiscount.TranItemID
  LEFT JOIN vEmployee PrimaryEmployee 
    ON Employees.PrimarySalesEmployeeID = PrimaryEmployee.EmployeeID
  LEFT JOIN vEmployee SecondaryEmployee 
    ON Employees.SecondarySalesEmployeeID = SecondaryEmployee.EmployeeID
  JOIN vMembership Membership 
    ON MMSTran.MembershipID = Membership.MembershipID
  JOIN vProduct MembershipProduct 
    ON Membership.MembershipTypeID = MembershipProduct.ProductID
  JOIN vMember Member 
    ON MMSTran.MemberID = Member.MemberID
  JOIN vValCurrencyCode OriginalCurrencyCode 
    ON ISNULL(MMSTran.ValCurrencyCodeID,1) = OriginalCurrencyCode.ValCurrencyCodeID
 WHERE CASE WHEN #ReportRefunds.PostingMMSClubID = 9999 THEN TranItem.ClubID
            ELSE #ReportRefunds.PostingMMSClubID END = @MMSClubID

SELECT #ReportingData.MMSClubID,
       #ReportingData.SaleDateAndTime,
       #ReportingData.PostedDate,
       #ReportingData.SalesSource,
       #ReportingData.SourceProductID,
       #ReportingData.ProductDescription,
       #ReportingData.RevenueReportingDepartmentName,
       #ReportingData.RevenueProductGroup,
       #ReportingData.PrimarySellingTeamMemberID,
       #ReportingData.PrimarySellingTeamMember,
       #ReportingData.SecondarySellingTeamMemberID,
       #ReportingData.SecondarySellingTeamMember,
       #ReportingData.MembershipID,
       #ReportingData.MembershipTypeDescription,
       #ReportingData.MemberID,
       #ReportingData.MemberName,
       Cast(#ReportingData.RevenueQuantity as Decimal(16,6)) RevenueQuantity,
       Cast(#ReportingData.RevenueAmount as Decimal(16,6)) RevenueAmount,
       #ReportingData.SaleQuantity,
       #ReportingData.SaleAmount,
       #ReportingData.SaleAmount LocalCurrencySaleAmount,
       #ReportingData.TotalDiscountAmount,
       #ReportingData.TotalDiscountAmount LocalCurrencyTotalDiscountAmount,
       #ReportingData.DiscountAmount1,
       #ReportingData.DiscountAmount2,
       #ReportingData.DiscountAmount3,
       #ReportingData.DiscountAmount4,
       #ReportingData.DiscountAmount5,
       #ReportingData.Discount1,
       #ReportingData.Discount2,
       #ReportingData.Discount3,
       #ReportingData.Discount4,
       #ReportingData.Discount5,
       #ReportingData.SaleDimDateKey,
       #ReportingData.SaleDimTimeKey,
       #ReportingData.MemberFirstName,
       #ReportingData.MemberLastName,
       Cast(LocalCurrencyCode.CurrencyCode as Varchar(8)) CurrencyCode,
       #ReportingData.CurrencyCode LocalCurrencyCode,
       @RevenueReportingDepartmentNameCommaList RevenueReportingDepartmentNameCommaList,
       @HeaderDateRange HeaderDateRange,
       @ReportRunDateTime ReportRunDateTime,
       #ReportingData.SoldNotServicedFlag,
       CAST(CASE WHEN ValProductSalesChannel.ValProductSalesChannelID IS NOT NULL THEN 'LTF E-Commerce - ' + ValProductSalesChannel.Description
                 WHEN #ReportingData.TransactionEmployeeID in (-2,-4,-5) THEN TransactionEmployee.FirstName + ' ' + TransactionEmployee.LastName
                 ELSE 'MMS' END as Varchar(50)) SalesChannel,
       #ReportingData.CorporateTransferAmount,
       #ReportingData.DivisionName,
       #ReportingData.SubdivisionName,
       @HeaderDivisionList HeaderDivisionList,
       @HeaderSubdivisionList HeaderSubdivisionList
  FROM #ReportingData
  JOIN vClub Club 
    ON #ReportingData.MMSClubID = Club.ClubID
  JOIN vValCurrencyCode LocalCurrencyCode 
    ON Club.ValCurrencyCodeID = LocalCurrencyCode.ValCurrencyCodeID
  JOIN vPlanExchangeRate LocalCurrencyPlanExchangeRate 
    ON #ReportingData.CurrencyCode = LocalCurrencyPlanExchangeRate.FromCurrencyCode
   AND LocalCurrencyCode.CurrencyCode = LocalCurrencyPlanExchangeRate.ToCurrencyCode
   AND #ReportingData.TranYear = LocalCurrencyPlanExchangeRate.PlanYear
  LEFT JOIN vWebOrderMMSTran WebOrderMMSTran
    ON #ReportingData.MMSTranID = WebOrderMMSTran.MMSTranID
  LEFT JOIN vWebOrder WebOrder
    ON WebOrderMMSTran.WebOrderID = WebOrder.WebOrderID
  LEFT JOIN vValProductSalesChannel ValProductSalesChannel
    ON WebOrder.ValProductSalesChannelID = ValProductSalesChannel.ValProductSalesChannelID
  LEFT JOIN vEmployee TransactionEmployee
    ON #ReportingData. TransactionEmployeeID = TransactionEmployee.EmployeeID
ORDER BY SaleDimDateKey, SaleDimTimeKey, MemberLastName, MemberFirstName, MemberID

DROP TABLE #DimReportingHierarchy
DROP TABLE #TodayMMSTran
DROP TABLE #RefundTranIDs
DROP TABLE #ReportRefunds
DROP TABLE #ReportingData
DROP TABLE #TMPDiscount

END


