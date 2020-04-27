
CREATE PROC [dbo].[procCognos_PTCloseoutTracker] 


AS
BEGIN 
SET XACT_ABORT ON
SET NOCOUNT ON

DECLARE  @ReportDate DATETIME
SET @ReportDate = CONVERT(DATETIME, CONVERT(VARCHAR(10), Getdate(), 101) , 101)


DECLARE @StartDate DATETIME
DECLARE @EndDate DATETIME
DECLARE @ReportMonthNumberInYear INT
SET @StartDate = CASE WHEN @StartDate = 'Jan 1, 1900' THEN DATEADD(MONTH,DATEDIFF(MONTH,0,GETDATE()),0) ELSE @ReportDate END
SET @EndDate = CASE WHEN @EndDate = 'Jan 1, 1900' THEN CONVERT(DATETIME,CONVERT(VARCHAR,GETDATE()+1,101),101) ELSE DateAdd(day,1,@ReportDate) END
SET @ReportMonthNumberInYear = (SELECT CalendarMonthNumberInYear FROM vReportDimDate WHERE CalendarDate = @StartDate)

DECLARE @ReportDateDimDateKey INT
SET @ReportDateDimDateKey = (SELECT DimDateKey from vReportDimDate where CalendarDate = @StartDate)

DECLARE @ReportRunDateTime VARCHAR(21)
SET @ReportRunDateTime = Replace(Substring(convert(varchar, GetDate(), 100),1,6)+', '+Substring(convert(varchar, GetDate(), 100),8,10)+' '+Substring(convert(varchar,GetDate(), 100),18,2),'  ',' ')


------ Note - incorporates PT DSSR Category and row label logic which will need to be manually maintained 
SELECT DISTINCT ReportDimReportingHierarchy.DimReportingHierarchyKey,
                ReportDimReportingHierarchy.DivisionName,
                ReportDimReportingHierarchy.SubdivisionName,
                ReportDimReportingHierarchy.DepartmentName,
                ReportDimReportingHierarchy.ProductGroupName,
                ReportDimReportingHierarchy.ProductGroupSortOrder,
                ReportDimReportingHierarchy.RegionType,
				CASE WHEN SubdivisionName in('Endurance','Group Training','Mixed Combat Arts')				
	                 OR DepartmentName in('Pilates','Personal Training','Fitness Products','Lutsen 99er')			
			         THEN 'Move It'
		             WHEN DepartmentName in('Devices','Lab Testing','Metabolic Assessments','MyHealth Check','MyHealth Score','Metabolic Conditioning')				
	                 THEN 'Know It'	
		             ELSE 'Nourish It'
				END PTDSSRCategory,
	            CASE WHEN DepartmentName in('Small Group','LTF at Home')
                     THEN 'Small Group'
	                 WHEN DepartmentName in('LT Endurance','Golf','Cycle-PT','Run-PT','Tri-PT','Lutsen 99er')
	                 THEN 'LT Endurance'
	                 WHEN DepartmentName in('myHealth Check','myHealth Score')
	                 THEN 'myHealth Score'
	                 WHEN DepartmentName in('PT E-Commerce','PT Nutritionals')
	                 THEN 'Nutritional Products'
	                 ELSE DepartmentName
	            END PTDSSRRowLabel
  INTO #DimReportingHierarchy
  FROM vReportDimReportingHierarchy ReportDimReportingHierarchy
    WHERE DivisionName = 'Personal Training'




SELECT DISTINCT Club.ClubID MMSClubID,
       PTRCLArea.Description Region,
       CASE WHEN Club.ValPreSaleID = 4 THEN 'Initial'
            WHEN Club.ValPreSaleID in (2,3,5,6) THEN 'Presale'
            WHEN Club.ClubDeactivationDate <= @StartDate THEN 'Closed'
            WHEN Club.ValPreSaleID = 1 THEN 'Open'
            ELSE '' END ClubStatus,
       Club.ClubActivationDate,
       Club.ValCurrencyCodeID
  INTO #Club
  FROM vClub Club
  JOIN vValRegion ValRegion
    ON Club.ValRegionID = ValRegion.ValRegionID
  JOIN vValPTRCLArea PTRCLArea
    ON Club.ValPTRCLAreaID = PTRCLArea.ValPTRCLAreaID


SELECT MMSTran.MMSTranID,
       MMSTran.ClubID,
       MMStran.PostDateTime,
       MMSTran.ReasonCodeID,
       MMSTran.MembershipID,
       MMSTran.ValTranTypeID,
       MMSTran.ReverseTranFlag
  INTO #TodayMMSTran
  FROM vMMSTran MMSTran
  JOIN #Club #Clubs
    ON MMSTran.ClubID = #Clubs.MMSClubID
WHERE MMSTran.PostDateTime >= @StartDate
AND MMSTran.PostDateTime < @EndDate
   AND IsNull(MMSTran.TranVoidedID,0) = 0
   AND MMSTran.ValTranTypeID in (1,3,4,5)

   option(recompile)   ------ added for performance 



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
WHERE #TodayMMSTran.ValTranTypeID = 5

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
SELECT CASE WHEN #TodayMMSTran.ClubID = 9999 THEN TranItem.ClubID
            WHEN #TodayMMSTran.ClubID = 13 THEN Membership.ClubID
            ELSE #TodayMMSTran.ClubID END AS MMSClubID, 
       Sum(CASE WHEN #DimReportingHierarchy.DepartmentName = '90 Day Weight Loss' 
	                    AND @ReportMonthNumberInYear in(1,4,7,10)  ---- Revenue deferred to 2nd month in Qtr.
	            THEN 0
				ELSE TranItem.ItemAmount
				END) SaleAmount,
       SUM(CASE WHEN TranItem.ItemAmount != 0 THEN SIGN(TranItem.ItemAmount)
                WHEN TranItem.ItemDiscountAmount != 0 THEN SIGN(TranItem.ItemDiscountAmount) * TranItem.Quantity
                WHEN (#TodayMMSTran.ValTranTypeID != 5 AND #TodayMMSTran.ReverseTranFlag = 1)
                     OR (#TodayMMSTran.ValTranTypeID = 5 AND #TodayMMSTran.ReverseTranFlag = 0) THEN -1 * TranItem.Quantity
                ELSE TranItem.Quantity END * ReportDimProduct.CorporateTransferMultiplier) CorporateTransferAmount,
       #DimReportingHierarchy.DepartmentName RevenueReportingDepartmentName,
	   #DimReportingHierarchy.PTDSSRCategory,
	   #DimReportingHierarchy.PTDSSRRowLabel
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
        #DimReportingHierarchy.DepartmentName,
	    #DimReportingHierarchy.PTDSSRCategory,
	    #DimReportingHierarchy.PTDSSRRowLabel

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
       #DimReportingHierarchy.DepartmentName RevenueReportingDepartmentName,
	   #DimReportingHierarchy.PTDSSRCategory,
	   #DimReportingHierarchy.PTDSSRRowLabel
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
          #DimReportingHierarchy.DepartmentName,
		  #DimReportingHierarchy.PTDSSRCategory,
	      #DimReportingHierarchy.PTDSSRRowLabel 

--Result Set
SELECT @ReportDateDimDateKey as ReportDimDateKey,
       ReportingData.RevenueReportingDepartmentName,
	   ReportingData.PTDSSRCategory,
	   ReportingData.PTDSSRRowLabel,
	   ReportingData.MMSClubID,
	   Club.ClubCode,
	   PTRCLArea.Description AS PTRCLArea,  
       Sum(ReportingData.SaleAmount + ReportingData.CorporateTransferAmount) ReportDateRevenue,
	   0 AS MTDRevenue,
	   0 AS GoalDollarAmount,
	   0 AS PriorYearRevenueForMonth,
	   @ReportRunDateTime AS ReportRunDateTime
  FROM #ReportingData ReportingData
   JOIN vClub Club
     ON ReportingData.MMSClubID = Club.ClubID
   JOIN vValPTRCLArea PTRCLArea
     ON Club.ValPTRCLAreaID = PTRCLArea.ValPTRCLAreaID
   
                                       
GROUP BY MMSClubID, RevenueReportingDepartmentName,Club.ClubCode,PTRCLArea.Description,
         ReportingData.PTDSSRCategory,ReportingData.PTDSSRRowLabel






DROP TABLE #RefundTranIDs
DROP TABLE #ReportRefunds
DROP TABLE #ReportingData
DROP TABLE #Club

DROP TABLE #DimReportingHierarchy
DROP TABLE #TodayMMSTran


END
