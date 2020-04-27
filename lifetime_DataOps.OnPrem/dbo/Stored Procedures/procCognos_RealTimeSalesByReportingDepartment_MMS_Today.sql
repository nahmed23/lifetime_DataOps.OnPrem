


CREATE PROC [dbo].[procCognos_RealTimeSalesByReportingDepartment_MMS_Today] (
    @DepartmentMinDimReportingHierarchyKeyList VARCHAR(8000),
    @DivisionList VARCHAR(8000),
    @SubdivisionList VARCHAR(8000),
    @RegionList VARCHAR(8000),
    @ClubIDList VARCHAR(8000)
)


AS
BEGIN 
SET XACT_ABORT ON
SET NOCOUNT ON

IF 1=0 BEGIN
       SET FMTONLY OFF
     END

 ----- Execution Sample
 ----- Exec procCognos_RealTimeSalesByReportingDepartment_MMS_Today '-1','Personal Training','All Subdivisions','All Regions','-1'


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

DECLARE @SSSGGrandOpeningDeadlineDate DATETIME
SET @SSSGGrandOpeningDeadlineDate = DATEADD(YY,-1,@EndDate)

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
        @RevenueReportingDepartmentNameCommaList VARCHAR(8000),
        @DepartmentMinKeyList VARCHAR(8000)

SELECT @HeaderDivisionList = STUFF((SELECT DISTINCT ','+DivisionName
                                      FROM #DimReportingHierarchy
                                       FOR XML PATH('')),1,1,''),
       @HeaderSubdivisionList = Case when @SubdivisionList = 'All Subdivisions' then 'All Subdivisions' 
	                                 ELSE STUFF((SELECT DISTINCT ','+SubdivisionName
                                         FROM #DimReportingHierarchy
                                          FOR XML PATH('')),1,1,'') End,
       @RevenueReportingDepartmentNameCommaList = Case when @DepartmentMinDimReportingHierarchyKeyList like '%-1%'  then 'All Departments'
	                                 ELSE STUFF((SELECT DISTINCT ','+DepartmentName
                                                           FROM #DimReportingHierarchy
                                                            FOR XML PATH('')),1,1,'') End,
       @DepartmentMinKeyList = STUFF((SELECT DISTINCT '|'+Convert(Varchar,MIN(DimReportingHierarchyKey))
                                        FROM #DimReportingHierarchy
                                       GROUP BY DivisionName,
                                                SubdivisionName,
                                                DepartmentName
                                         FOR XML PATH('')),1,1,'')

DECLARE @RegionType VARCHAR(50)
SELECT @RegionType = CASE WHEN COUNT(DISTINCT RegionType) > 1 THEN 'MMS Region'
                          ELSE MIN(RegionType) END
  FROM #DimReportingHierarchy

SELECT DISTINCT Club.ClubID MMSClubID,
       CASE WHEN @RegionType = 'PT RCL Area' THEN PTRCLArea.Description
            WHEN @RegionType = 'Member Activities Region' THEN MemberActivityRegion.Description
            ELSE ValRegion.Description END Region,
       CASE WHEN Club.ValPreSaleID = 4 THEN 'Initial'
            WHEN Club.ValPreSaleID in (2,3,5,6) THEN 'Presale'
            WHEN Club.ClubDeactivationDate <= GetDate() THEN 'Closed'
            WHEN Club.ValPreSaleID = 1 THEN 'Open'
            ELSE '' END ClubStatus,
       Club.ClubActivationDate,
       Club.ValCurrencyCodeID
  INTO #Club
  FROM vClub Club
  JOIN fnParsePipeList(@ClubIDList) MMSClubIDList
    ON Convert(Varchar,Club.ClubID) = MMSClubIDList.Item
    OR @ClubIDList like '%-1%'
  JOIN vValRegion ValRegion
    ON Club.ValRegionID = ValRegion.ValRegionID
  JOIN fnParsePipeList(@RegionList) RegionList
    ON ValRegion.Description = RegionList.Item
      OR @RegionList like '%All Regions%'
  JOIN vValMemberActivityRegion MemberActivityRegion
    ON Club.ValMemberActivityRegionID = MemberActivityRegion.ValMemberActivityRegionID
  JOIN vValPTRCLArea PTRCLArea
    ON Club.ValPTRCLAreaID = PTRCLArea.ValPTRCLAreaID
 WHERE Club.ClubID NOT IN (-1,99,100)
   AND Club.ClubID < 900

SELECT MMSTran.MMSTranID,
       MMSTran.ClubID,
       MMStran.PostDateTime,
       MMSTran.ReasonCodeID,
       MMSTran.MembershipID,
       MMSTran.ValTranTypeID,
       MMSTran.ReverseTranFlag
  INTO #TodayMMSTran
  FROM vMMSTranNonArchive MMSTran
  JOIN #Club #Clubs
    ON MMSTran.ClubID = #Clubs.MMSClubID
 WHERE MMSTran.PostDateTime >= Convert(Datetime,Convert(Varchar,GetDate(),101),101)
   AND MMSTran.TranVoidedID is NULL
   AND MMSTran.ValTranTypeID in (1,3,4,5)
   AND @IncludeTodaysTransactionsFlag = 'Y'

SELECT MMSTranRefund.MMSTranRefundID,
       #TodayMMSTran.MMSTranID RefundMMSTranID,
       #TodayMMSTran.ReasonCodeID RefundReasonCodeID,
       Membership.ClubID MembershipClubID
  INTO #RefundTranIDs
  FROM vMMSTranRefund MMSTranRefund
  JOIN #TodayMMSTran
    ON MMSTranRefund.MMSTranID = #TodayMMSTran.MMSTranID
  JOIN vMembership Membership 
    ON Membership.MembershipID = #TodayMMSTran.MembershipID
  JOIN #Club #Clubs
    ON Membership.ClubID = #Clubs.MMSClubID

SELECT #RefundTranIDs.RefundMMSTranID,
       CASE WHEN #RefundTranIDs.RefundReasonCodeID = 108 OR MMSTran.ClubID in (13) THEN #RefundTranIDs.MembershipClubID
            ELSE MMSTran.ClubID END AS PostingMMSClubID
  INTO #ReportRefunds
  FROM #RefundTranIDs
  JOIN vMMSTranRefundMMSTran MMSTranRefundMMSTran 
    ON MMSTranRefundMMSTran.MMSTranRefundID = #RefundTranIDs.MMSTranRefundID
  JOIN vMMSTran MMSTran 
    ON MMSTran.MMSTranID = MMSTranRefundMMSTran.OriginalMMSTranID
 GROUP BY #RefundTranIDs.RefundMMSTranID,
          CASE WHEN #RefundTranIDs.RefundReasonCodeID = 108 OR MMSTran.ClubID in (13) THEN #RefundTranIDs.MembershipClubID
               ELSE MMSTran.ClubID END 

--Non-Corporate internal transactions
SELECT CASE WHEN #TodayMMSTran.ClubID = 9999 THEN TranItem.ClubID
            WHEN #TodayMMSTran.ClubID = 13 THEN Membership.ClubID
            ELSE #TodayMMSTran.ClubID END AS MMSClubID, 
       Sum(TranItem.ItemAmount) SaleAmount,
       SUM(CASE WHEN TranItem.ItemAmount != 0 THEN SIGN(TranItem.ItemAmount)
                WHEN TranItem.ItemDiscountAmount != 0 THEN SIGN(TranItem.ItemDiscountAmount) * TranItem.Quantity
                WHEN (#TodayMMSTran.ValTranTypeID != 5 AND #TodayMMSTran.ReverseTranFlag = 1)
                     OR (#TodayMMSTran.ValTranTypeID = 5 AND #TodayMMSTran.ReverseTranFlag = 0) THEN -1 * TranItem.Quantity
                ELSE TranItem.Quantity END * ReportDimProduct.CorporateTransferMultiplier) CorporateTransferAmount,
       #DimReportingHierarchy.DepartmentName RevenueReportingDepartmentName
  INTO #ReportingData
  FROM #TodayMMSTran
  LEFT JOIN vMMSTranRefund MMSTranRefund
    ON #TodayMMSTran.MMSTranID = MMSTranRefund.MMSTranID
  JOIN vTranItem TranItem 
    ON #TodayMMSTran.MMSTranID = TranItem.MMSTranID
  JOIN vMembership Membership 
    ON #TodayMMSTran.MembershipID = Membership.MembershipID
  JOIN vReportDimProduct ReportDimProduct
    ON TranItem.ProductID = ReportDimProduct.MMSProductID
  JOIN #DimReportingHierarchy
    ON ReportDimProduct.DimReportingHierarchyKey = #DimReportingHierarchy.DimReportingHierarchyKey
 WHERE MMSTranRefund.MMSTranID IS NULL
 GROUP BY CASE WHEN #TodayMMSTran.ClubID = 9999 THEN TranItem.ClubID
               WHEN #TodayMMSTran.ClubID = 13 THEN Membership.ClubID                                                               
               ELSE #TodayMMSTran.ClubID END,
        #DimReportingHierarchy.DepartmentName

UNION ALL

--Automated Refunds
SELECT CASE WHEN #ReportRefunds.PostingMMSClubID = 9999 THEN TranItem.ClubID
            ELSE #ReportRefunds.PostingMMSClubID END MMSClubID,
       Sum(TranItem.ItemAmount) SaleAmount,
       SUM(CASE WHEN TranItem.ItemAmount != 0 THEN SIGN(TranItem.ItemAmount)
                WHEN TranItem.ItemDiscountAmount != 0 THEN SIGN(TranItem.ItemDiscountAmount) * TranItem.Quantity
                WHEN (MMSTran.ValTranTypeID != 5 AND MMSTran.ReverseTranFlag = 1)
                     OR (MMSTran.ValTranTypeID = 5 AND MMSTran.ReverseTranFlag = 0) THEN -1 * TranItem.Quantity
                ELSE TranItem.Quantity END * ReportDimProduct.CorporateTransferMultiplier) CorporateTransferAmount,
       #DimReportingHierarchy.DepartmentName RevenueReportingDepartmentName
  FROM #TodayMMSTran MMSTran
  JOIN #ReportRefunds
    ON #ReportRefunds.RefundMMSTranID = MMSTran.MMSTranID
  JOIN vTranItem TranItem
    ON MMSTran.MMSTranID = TranItem.MMSTranID
  JOIN vReportDimProduct ReportDimProduct
    ON TranItem.ProductID = ReportDimProduct.MMSProductID
  JOIN #DimReportingHierarchy
    ON ReportDimProduct.DimReportingHierarchyKey = #DimReportingHierarchy.DimReportingHierarchyKey
 GROUP BY CASE WHEN #ReportRefunds.PostingMMSClubID = 9999 THEN TranItem.ClubID
               ELSE #ReportRefunds.PostingMMSClubID END,
          #DimReportingHierarchy.DepartmentName 

SELECT MMSClubID,
       RevenueReportingDepartmentName,
       SUM(SaleAmount + CorporateTransferAmount) SaleAmount
  INTO #ReportingDataSummary
  FROM #ReportingData
 GROUP BY MMSClubID, RevenueReportingDepartmentName

SELECT #ReportingDataSummary.MMSClubID,
       Sum(#ReportingDataSummary.SaleAmount) SaleAmount
  INTO #ClubSSSGRevenue
  FROM #ReportingDataSummary
  JOIN #Club
    ON #ReportingDataSummary.MMSClubID = #Club.MMSClubID
   AND #Club.ClubActivationDate <= @SSSGGrandOpeningDeadlineDate 
 GROUP BY #ReportingDataSummary.MMSClubID  

SELECT #Club.Region,
       #Club.ClubStatus,
       Sum(#ReportingDataSummary.SaleAmount) SaleAmount
  INTO #RegionSSSGRevenue       
  FROM #ReportingDataSummary
  JOIN #Club
    ON #ReportingDataSummary.MMSClubID = #Club.MMSClubID
   AND #Club.ClubActivationDate <= @SSSGGrandOpeningDeadlineDate 
 GROUP BY #Club.Region,
          #Club.ClubStatus

SELECT #Club.ClubStatus,
       Sum(#ReportingDataSummary.SaleAmount) SaleAmount
  INTO #StatusSSSGRevenue       
  FROM #ReportingDataSummary
  JOIN #Club
    ON #ReportingDataSummary.MMSClubID = #Club.MMSClubID
   AND #Club.ClubActivationDate <= @SSSGGrandOpeningDeadlineDate 
  GROUP BY #Club.ClubStatus
  
SELECT Sum(#ReportingDataSummary.SaleAmount) SaleAmount
  INTO #ReportSSSGRevenue   
  FROM #ReportingDataSummary
  JOIN #Club
    ON #ReportingDataSummary.MMSClubID = #Club.MMSClubID
   AND #Club.ClubActivationDate <= @SSSGGrandOpeningDeadlineDate 
 
 --SSSG summary
SELECT #Club.MMSClubID,
       #ClubSSSGRevenue.SaleAmount PromptYearClubActualAmount,
       #RegionSSSGRevenue.SaleAmount PromptYearRegionActualAmount,
       #StatusSSSGRevenue.SaleAmount PromptYearStatusActualAmount,
       #ReportSSSGRevenue.SaleAmount PromptYearReportActualAmount 
  INTO #SSSGSummary
  FROM #Club
  LEFT JOIN #ClubSSSGRevenue
    ON #Club.MMSClubID =#ClubSSSGRevenue.MMSClubID
  LEFT JOIN #RegionSSSGRevenue
    ON #Club.Region = #RegionSSSGRevenue.Region
   AND #Club.ClubStatus = #RegionSSSGRevenue.ClubStatus
  LEFT JOIN #StatusSSSGRevenue
    ON #Club.ClubStatus = #StatusSSSGRevenue.ClubStatus
  CROSS JOIN #ReportSSSGRevenue

--Result Set
SELECT #ReportingDataSummary.MMSClubID,
       Sum(#ReportingDataSummary.SaleAmount) SaleAmount,
       #ReportingDataSummary.RevenueReportingDepartmentName,
       @HeaderDateRange HeaderDateRange,
       2 SortOrder,
       ValCurrencyCode.CurrencyCode CurrencyCode,
       @ReportRunDateTime ReportRunDateTime,
       0.00 GoalAmount,
       @RevenueReportingDepartmentNameCommaList RevenueReportingDepartmentNameCommaList,
       0 ClubPriorYearActual,
       0 RegionPriorYearActual,
       0 StatusPriorYearActual,
       0 ReportPriorYearActual,
       0 SSSGClubPromptYearActual,
       @HeaderDivisionList HeaderDivisionList,
       @HeaderSubdivisionList HeaderSubdivisionList,
       Sum(#ReportingDataSummary.SaleAmount) EndDateActual,
       @DepartmentMinKeyList DepartmentMinDimReportingHierarchyKeyList
  FROM #ReportingDataSummary
  JOIN #Club
    ON #ReportingDataSummary.MMSClubID = #Club.MMSClubID
  JOIN vValCurrencyCode ValCurrencyCode 
    ON #Club.ValCurrencyCodeID = ValCurrencyCode.ValCurrencyCodeID
  LEFT JOIN #SSSGSummary 
    ON #ReportingDataSummary.MMSClubID = #SSSGSummary.MMSClubID                                       
GROUP BY #ReportingDataSummary.MMSClubID, RevenueReportingDepartmentName, ValCurrencyCode.CurrencyCode

UNION ---

SELECT #ReportingDataSummary.MMSClubID,
       Sum(#ReportingDataSummary.SaleAmount) SaleAmount,
       'Total' RevenueReportingDepartmentName,
       @HeaderDateRange HeaderDateRange,
       1 SortOrder,
       ValCurrencyCode.CurrencyCode CurrencyCode,
       @ReportRunDateTime ReportRunDateTime,
       0.00 GoalAmount,
       @RevenueReportingDepartmentNameCommaList RevenueReportingDepartmentNameCommaList,
       0 ClubPriorYearActual,
       0 RegionPriorYearActual,
       0 StatusPriorYearActual,
       0 ReportPriorYearActual,
       Min(#SSSGSummary.PromptYearClubActualAmount) SSSGClubPromptYearActual,
       @HeaderDivisionList HeaderDivisionList,
       @HeaderSubdivisionList HeaderSubdivisionList,
       Sum(#ReportingDataSummary.SaleAmount) EndDateActual,
       @DepartmentMinKeyList DepartmentMinDimReportingHierarchyKeyList
  FROM #ReportingDataSummary
  JOIN #Club
    ON #ReportingDataSummary.MMSClubID = #Club.MMSClubID
  JOIN vValCurrencyCode ValCurrencyCode 
    ON #Club.ValCurrencyCodeID = ValCurrencyCode.ValCurrencyCodeID
  LEFT JOIN #SSSGSummary 
    ON #ReportingDataSummary.MMSClubID = #SSSGSummary.MMSClubID
 GROUP BY #ReportingDataSummary.MMSClubID, ValCurrencyCode.CurrencyCode
 ORDER BY MMSClubID, RevenueReportingDepartmentName

DROP TABLE #RefundTranIDs
DROP TABLE #ReportRefunds
DROP TABLE #ReportingData
DROP TABLE #Club
DROP TABLE #ClubSSSGRevenue
DROP TABLE #DimReportingHierarchy
DROP TABLE #RegionSSSGRevenue
DROP TABLE #ReportSSSGRevenue
DROP TABLE #ReportingDataSummary
DROP TABLE #SSSGSummary
DROP TABLE #StatusSSSGRevenue
DROP TABLE #TodayMMSTran

END


