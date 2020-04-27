


CREATE PROC [dbo].[procCognos_RevenueClubSummary_ByReportingDepartment_MMS] (
     @StartPostDate Datetime,
     @EndPostDate Datetime,
     @RevenueReportingDepartmentList Varchar(2000)
)

AS
BEGIN 
SET XACT_ABORT ON
SET NOCOUNT ON

DECLARE @AdjustedEndPostDate SMALLDATETIME
DECLARE @StartDate DATETIME
DECLARE @EndDate DATETIME

--	inverted values assigned to @StartDate and @EndDate to comply with conditional logic below, determining which data source to use;
  SET @StartDate = DATEADD(mm,DATEDIFF(mm,0,GETDATE()),0) --First Day of this month
  SET @EndDate = CONVERT(DATETIME,CONVERT(VARCHAR(11),GETDATE())) --Today (the first moment, ie: 3/4/08 00:00:00 )

  SET @AdjustedEndPostDate = DATEADD(dd, 1, @EndPostDate)

--HeaderDateRange to MMM. D, YYYY
DECLARE @HeaderDateRangeStart Varchar(50)
DECLARE @HeaderDateRangeEnd Varchar(50)
DECLARE @HeaderDateRange Varchar(110)
SET @HeaderDateRangeStart = SubString(ConverT(Varchar,@StartPostDate),1,3)+' '+LTRIM(SubString(Convert(Varchar,@StartPostDate),5,DataLength(Convert(Varchar,@StartPostDate))-12))
SET @HeaderDateRangeEnd = SubString(ConverT(Varchar,@EndPostDate),1,3)+' '+LTRIM(SubString(Convert(Varchar,@EndPostDate),5,DataLength(Convert(Varchar,@EndPostDate))-12))
SET @HeaderDateRange = Replace(@HeaderDateRangeStart,' '+Convert(Varchar,Year(@StartPostDate)),', '+Convert(Varchar,Year(@StartPostDate))) + ' through ' + 
                       Replace(@HeaderDateRangeEnd,' '+Convert(Varchar,Year(@EndPostDate)),', '+Convert(Varchar,Year(@EndPostDate)))


--Get parameter departments
CREATE TABLE #tmpList (StringField VARCHAR(50))
EXEC procParseStringList @RevenueReportingDepartmentList

CREATE TABLE #ReportingData (
  ClubStatus Varchar(50),
  Region Varchar(50),
  ClubCode Varchar(5),
  RevenueReportingDepartment Varchar(50),
  ActualRevenue Numeric(10,2),
  HeaderDateRange Varchar(50),
  ClubName Varchar(50),
  MMSClubID Int,
  SortOrder Int
)

IF @StartPostDate >= @StartDate AND @EndPostDate < @EndDate
BEGIN

INSERT INTO #ReportingData

SELECT CASE WHEN Club.ValPresaleID = 1 THEN 'Open Clubs'
            WHEN Club.ValPresaleID = 4 THEN 'Not Open For PreSale'
            ELSE 'PreSale Clubs'
         END ClubStatus,
       ValPTRCLArea.Description Region,
       Club.ClubCode,
       ValProductGroup.RevenueReportingDepartment,
       Sum(MMSRevenueReportSummary.ItemAmount) ActualRevenue,
       @HeaderDateRange HeaderDateRange,
       Club.ClubName,
       Club.ClubID,
       2 as SortOrder
FROM vMMSRevenueReportSummary MMSRevenueReportSummary
JOIN vProductGroup ProductGroup
  ON MMSRevenueReportSummary.ProductID = ProductGroup.ProductID
JOIN vValProductGroup ValProductGroup
  ON ProductGroup.ValProductGroupID = ValProductGroup.ValProductGroupID
JOIN vClub Club
  ON MMSRevenueReportSummary.PostingClubID = Club.ClubID
JOIN vValPTRCLArea ValPTRCLArea
  ON ValPTRCLArea.ValPTRCLAreaID = Club.ValPTRCLAreaID
JOIN #tmpList
  ON #tmpList.StringField = ValProductGroup.RevenueReportingDepartment
WHERE MMSRevenueReportSummary.PostDateTime >= @StartPostDate
  AND MMSRevenueReportSummary.PostDateTime < @AdjustedEndPostDate
GROUP BY CASE WHEN Club.ValPresaleID = 1 THEN 'Open Clubs'
              WHEN Club.ValPresaleID = 4 THEN 'Not Open For PreSale'
              ELSE 'PreSale Clubs'
           END,
       ValPTRCLArea.Description,
       Club.ClubCode,
       ValProductGroup.RevenueReportingDepartment,
       Club.ClubName,
       Club.ClubID

UNION

SELECT CASE WHEN Club.ValPresaleID = 1 THEN 'Open Clubs'
            WHEN Club.ValPresaleID = 4 THEN 'Not Open For PreSale'
            ELSE 'PreSale Clubs'
         END ClubStatus,
       ValPTRCLArea.Description Region,
       Club.ClubCode,
       'Total' RevenueReportingDepartment,
       Sum(MMSRevenueReportSummary.ItemAmount) ActualRevenue,
       @HeaderDateRange HeaderDateRange,
       Club.ClubName,
       Club.ClubID,
       1 as SortOrder
FROM vMMSRevenueReportSummary MMSRevenueReportSummary
JOIN vProductGroup ProductGroup
  ON MMSRevenueReportSummary.ProductID = ProductGroup.ProductID
JOIN vValProductGroup ValProductGroup
  ON ProductGroup.ValProductGroupID = ValProductGroup.ValProductGroupID
JOIN vClub Club
  ON MMSRevenueReportSummary.PostingClubID = Club.ClubID
JOIN vValPTRCLArea ValPTRCLArea
  ON ValPTRCLArea.ValPTRCLAreaID = Club.ValPTRCLAreaID
JOIN #tmpList
  ON #tmpList.StringField = ValProductGroup.RevenueReportingDepartment
WHERE MMSRevenueReportSummary.PostDateTime >= @StartPostDate
  AND MMSRevenueReportSummary.PostDateTime < @AdjustedEndPostDate
GROUP BY CASE WHEN Club.ValPresaleID = 1 THEN 'Open Clubs'
              WHEN Club.ValPresaleID = 4 THEN 'Not Open For PreSale'
              ELSE 'PreSale Clubs'
           END,
       ValPTRCLArea.Description,
       Club.ClubCode,
       Club.ClubName,
       Club.ClubID
END
ELSE
BEGIN
CREATE TABLE #RefundTranIDs (
  MMSTranRefundID Int,
  RefundMMSTranID Int,
  RefundReasonCodeID Int,
  MembershipClubID Int,
  MembershipClubName Varchar(50),
  MembershipRegionDescription Varchar(50)
)

INSERT INTO #RefundTranIDs

SELECT MMSTranRefund.MMSTranRefundID,
       MMSTran.MMSTranID,
       MMSTran.ReasonCodeID,
       Membership.ClubID,
       Club.ClubName,
       ValPTRCLArea.Description
FROM vMMSTranRefund MMSTranRefund
JOIN vMMSTran MMSTran
  ON MMSTranRefund.MMSTranID = MMSTran.MMSTranID
JOIN vMembership Membership
  ON Membership.MembershipID = MMSTran.MembershipID
JOIN vClub Club
  ON Club.ClubID = Membership.ClubID
JOIN vTranItem TranItem
  ON TranItem.MMSTranID = MMSTran.MMSTranID
JOIN vProduct Product
  ON Product.ProductID = TranItem.ProductID
JOIN vProductGroup ProductGroup
  ON Product.ProductID = ProductGroup.ProductID
JOIN vValProductGroup ValProductGroup
  ON ProductGroup.ValProductGroupID = ValProductGroup.ValProductGroupID
JOIN vValPTRCLArea ValPTRCLArea
  ON Club.ValPTRCLAreaID = ValPTRCLArea.ValPTRCLAreaID
JOIN #tmpList 
  ON #tmpList.StringField = ValProductGroup.RevenueReportingDepartment
WHERE MMSTran.TranVoidedID is NULL
  AND MMSTran.PostDateTime >= @StartPostDate
  AND MMSTran.PostDateTime < @AdjustedEndPostDate

CREATE TABLE #ReportRefunds (
  RefundMMSTranID Int,
  PostingRegionDescription Varchar(50),
  PostingClubName Varchar(50),
  PostingMMSClubID Int
)

INSERT INTO #ReportRefunds

SELECT #RefundTranIDs.RefundMMSTranID,
       CASE WHEN TranClub.ClubID = 9999 THEN 
		         CASE WHEN TranItemClub.ClubID IS NULL THEN ValPTRCLArea.Description
                      ELSE TranItemValPTRCLArea.Description END
            WHEN #RefundTranIDs.RefundReasonCodeID = 108 OR TranClub.ClubID in (13)
                 THEN #RefundTranIDs.MembershipRegionDescription
            ELSE ValPTRCLArea.Description
         END PostingRegionDescription,
       CASE WHEN TranClub.ClubID = 9999 THEN
                 CASE WHEN TranItemClub.ClubID IS NULL THEN TranClub.ClubName
                      ELSE TranItemClub.ClubName END       
            WHEN #RefundTranIDs.RefundReasonCodeID = 108 OR TranClub.ClubID in (13)
                 THEN #RefundTranIDs.MembershipClubName
            ELSE TranClub.ClubName
         END PostingClubName,
       CASE WHEN TranClub.ClubID = 9999 THEN
                 CASE WHEN TranItemClub.ClubID IS NULL THEN TranClub.ClubID
                      ELSE TranItemClub.ClubID END
            WHEN #RefundTranIDs.RefundReasonCodeID = 108 OR TranClub.ClubID in (13)
                 THEN #RefundTranIDs.MembershipClubID
            ELSE TranClub.ClubID
         END PostingMMSClubID
FROM #RefundTranIDs
JOIN vMMSTranRefundMMSTran MMSTranRefundMMSTran
  ON MMSTranRefundMMSTran.MMSTranRefundID = #RefundTranIDs.MMSTranRefundID
JOIN vMMSTran MMSTran
  ON MMSTran.MMSTranID = MMSTranRefundMMSTran.OriginalMMSTranID
JOIN vClub TranClub
  ON TranClub.ClubID = MMSTran.ClubID
JOIN vValPTRCLArea ValPTRCLArea
  ON ValPTRCLArea.ValPTRCLAreaID = TranClub.ValPTRCLAreaID
LEFT JOIN vTranItem TranItem
  ON MMSTran.MMSTranID = TranItem.MMSTranID
LEFT JOIN vClub TranItemClub
  ON TranItem.ClubID = TranItemClub.ClubID
LEFT JOIN vValPTRCLArea TranItemValPTRCLArea
  ON TranItemValPTRCLArea.ValPTRCLAreaID = TranItemClub.ValPTRCLAreaID
GROUP BY #RefundTranIDs.RefundMMSTranID,
         CASE WHEN TranClub.ClubID = 9999 THEN 
		           CASE WHEN TranItemClub.ClubID IS NULL THEN ValPTRCLArea.Description
                        ELSE TranItemValPTRCLArea.Description END
              WHEN #RefundTranIDs.RefundReasonCodeID = 108 OR TranClub.ClubID in (13)
                   THEN #RefundTranIDs.MembershipRegionDescription
              ELSE ValPTRCLArea.Description
         END,
         CASE WHEN TranClub.ClubID = 9999 THEN
                   CASE WHEN TranItemClub.ClubID IS NULL THEN TranClub.ClubName
                        ELSE TranItemClub.ClubName END       
              WHEN #RefundTranIDs.RefundReasonCodeID = 108 OR TranClub.ClubID in (13)
                   THEN #RefundTranIDs.MembershipClubName
              ELSE TranClub.ClubName
         END,
         CASE WHEN TranClub.ClubID = 9999 THEN
                   CASE WHEN TranItemClub.ClubID IS NULL THEN TranClub.ClubID
                        ELSE TranItemClub.ClubID END
              WHEN #RefundTranIDs.RefundReasonCodeID = 108 OR TranClub.ClubID in (13)
                   THEN #RefundTranIDs.MembershipClubID
              ELSE TranClub.ClubID
         END


--Non-Corporate Internal transaction data
INSERT INTO #ReportingData

SELECT CASE WHEN Club.ValPresaleID = 1 THEN 'Open Clubs'
            WHEN Club.ValPresaleID = 4 THEN 'Not Open For PreSale'
            ELSE 'PreSale Clubs'
         END ClubStatus,
       CASE WHEN Club.ClubID = 9999 THEN
            CASE WHEN TranItemClub.ClubID IS NULL THEN ValPTRCLArea.Description
                 ELSE TranItemValPTRCLArea.Description END
            ELSE ValPTRCLArea.Description
       END AS Region,
       CASE WHEN Club.ClubID = 9999 THEN                                            
            CASE WHEN TranItemClub.ClubID IS NULL THEN Club.ClubCode               
                 ELSE TranItemClub.ClubCode END                                    
            ELSE Club.ClubCode                                                     
       END AS ClubCode,
       ValProductGroup.RevenueReportingDepartment,
       Sum(TranItem.ItemAmount) ActualRevenue,
       @HeaderDateRange HeaderDateRange,
       CASE WHEN Club.ClubID = 9999 THEN                                            
            CASE WHEN TranItemClub.ClubID IS NULL THEN Club.ClubName               
                 ELSE TranItemClub.ClubName END                                    
            ELSE Club.ClubName                                                     
       END AS ClubName,  
       CASE WHEN Club.ClubID = 9999 THEN                                            
            CASE WHEN TranItemClub.ClubID IS NULL THEN Club.ClubID               
                 ELSE TranItemClub.ClubID END                                    
            ELSE Club.ClubID
       END AS ClubID, 
       2 as SortOrder
FROM vMMSTran MMSTran
JOIN vClub Club
  ON MMSTran.ClubID = Club.ClubID
JOIN vTranItem TranItem
  ON MMSTran.MMSTranID = TranItem.MMSTranID
LEFT JOIN vClub TranItemClub
  ON TranItem.ClubID = TranItemClub.ClubID
LEFT JOIN vValPTRCLArea TranItemValPTRCLArea
  ON TranItemValPTRCLArea.ValPTRCLAreaID = TranItemClub.ValPTRCLAreaID
JOIN vProduct Product
  ON Product.ProductID = TranItem.ProductID
JOIN vProductGroup ProductGroup
  ON Product.ProductID = ProductGroup.ProductID
JOIN vValProductGroup ValProductGroup
  ON ProductGroup.ValProductGroupID = ValProductGroup.ValProductGroupID
JOIN vValPTRCLArea ValPTRCLArea
  ON ValPTRCLArea.ValPTRCLAreaID = Club.ValPTRCLAreaID
JOIN #tmpList
  ON #tmpList.StringField = ValProductGroup.RevenueReportingDepartment
LEFT JOIN vMMSTranRefund MMSTranRefund
  ON MMSTran.MMSTranID = MMSTranRefund.MMSTranID
WHERE MMSTran.PostDateTime >= @StartPostDate
  AND MMSTran.PostDateTime < @AdjustedEndPostDate
  AND MMSTran.TranVoidedID is NULL
  AND MMSTran.ValTranTypeID in (1,3,4,5)
  AND MMSTranRefund.MMSTranRefundID is NULL
  AND Club.ClubID not in (13)
GROUP BY CASE WHEN Club.ValPresaleID = 1 THEN 'Open Clubs'
              WHEN Club.ValPresaleID = 4 THEN 'Not Open For PreSale'
              ELSE 'PreSale Clubs'
           END,
       --ValPTRCLArea.Description,
       CASE WHEN Club.ClubID = 9999 THEN
            CASE WHEN TranItemClub.ClubID IS NULL THEN ValPTRCLArea.Description
                 ELSE TranItemValPTRCLArea.Description END
            ELSE ValPTRCLArea.Description END,
       CASE WHEN Club.ClubID = 9999 THEN                                            
            CASE WHEN TranItemClub.ClubID IS NULL THEN Club.ClubCode               
                 ELSE TranItemClub.ClubCode END                                    
            ELSE Club.ClubCode END,
       ValProductGroup.RevenueReportingDepartment,
       CASE WHEN Club.ClubID = 9999 THEN                                            
            CASE WHEN TranItemClub.ClubID IS NULL THEN Club.ClubName               
                 ELSE TranItemClub.ClubName END                                    
            ELSE Club.ClubName END,
       CASE WHEN Club.ClubID = 9999 THEN                                            
            CASE WHEN TranItemClub.ClubID IS NULL THEN Club.ClubID               
                 ELSE TranItemClub.ClubID END                                    
            ELSE Club.ClubID END 

--Corporate Internal transaction data
INSERT INTO #ReportingData

SELECT CASE WHEN Club.ValPresaleID = 1 THEN 'Open Clubs'
            WHEN Club.ValPresaleID = 4 THEN 'Not Open For PreSale'
            ELSE 'PreSale Clubs'
         END ClubStatus,
       ValPTRCLArea.Description Region,
       Club.ClubCode,
       ValProductGroup.RevenueReportingDepartment,
       Sum(TranItem.ItemAmount) ActualRevenue,
       @HeaderDateRange HeaderDateRange,
       Club.ClubName,
       Club.ClubID,
       2 as SortOrder
FROM vMMSTran MMSTran
JOIN vTranItem TranItem
  ON MMSTran.MMSTranID = TranItem.MMSTranID
JOIN vProduct Product
  ON Product.ProductID = TranItem.ProductID
JOIN vProductGroup ProductGroup
  ON Product.ProductID = ProductGroup.ProductID
JOIN vValProductGroup ValProductGroup
  ON ProductGroup.ValProductGroupID = ValProductGroup.ValProductGroupID
JOIN #tmpList
  ON #tmpList.StringField = ValProductGroup.RevenueReportingDepartment
JOIN vMembership Membership
  ON MMSTran.MembershipID = Membership.MembershipID
JOIN vClub Club
  ON Membership.ClubID = Club.ClubID
JOIN vValPTRCLArea ValPTRCLArea
  ON ValPTRCLArea.ValPTRCLAreaID = Club.ValPTRCLAreaID
LEFT JOIN vMMSTranRefund MMSTranRefund
  ON MMSTran.MMSTranID = MMSTranRefund.MMSTranID
WHERE MMSTran.PostDateTime >= @StartPostDate
  AND MMSTran.PostDateTime < @AdjustedEndPostDate
  AND MMSTran.TranVoidedID is NULL
  AND MMSTran.ValTranTypeID in (1,3,4,5)
  AND MMSTranRefund.MMSTranRefundID is NULL
  AND Club.ClubID in (13)
GROUP BY CASE WHEN Club.ValPresaleID = 1 THEN 'Open Clubs'
              WHEN Club.ValPresaleID = 4 THEN 'Not Open For PreSale'
              ELSE 'PreSale Clubs'
           END,
       ValPTRCLArea.Description,
       Club.ClubCode,
       ValProductGroup.RevenueReportingDepartment,
       Club.ClubName,
       Club.ClubID

--Automated Refunds
INSERT INTO #ReportingData

SELECT CASE WHEN Club.ValPresaleID = 1 THEN 'Open Clubs'
            WHEN Club.ValPresaleID = 4 THEN 'Not Open For PreSale'
            ELSE 'PreSale Clubs'
         END ClubStatus,
       ValPTRCLArea.Description Region,
       Club.ClubCode,
       ValProductGroup.RevenueReportingDepartment,
       Sum(TranItem.ItemAmount) ActualRevenue,
       @HeaderDateRange HeaderDateRange,
       Club.ClubName,
       Club.ClubID,
       2 as SortOrder
FROM vMMSTran MMSTran
JOIN #ReportRefunds
  ON #ReportRefunds.RefundMMSTranID = MMSTran.MMSTranID
JOIN vTranItem TranItem
  ON MMSTran.MMSTranID = TranItem.MMSTranID
JOIN vProduct Product
  ON Product.ProductID = TranItem.ProductID
JOIN vProductGroup ProductGroup
  ON Product.ProductID = ProductGroup.ProductID
JOIN vValProductGroup ValProductGroup
  ON ProductGroup.ValProductGroupID = ValProductGroup.ValProductGroupID
JOIN vClub Club
  ON #ReportRefunds.PostingMMSClubID = Club.ClubID
JOIN vValPTRCLArea ValPTRCLArea
  ON ValPTRCLArea.ValPTRCLAreaID = Club.ValPTRCLAreaID
JOIN #tmpList
  ON #tmpList.StringField = ValProductGroup.RevenueReportingDepartment
GROUP BY CASE WHEN Club.ValPresaleID = 1 THEN 'Open Clubs'
              WHEN Club.ValPresaleID = 4 THEN 'Not Open For PreSale'
              ELSE 'PreSale Clubs'
           END,
       ValPTRCLArea.Description,
       Club.ClubCode,
       ValProductGroup.RevenueReportingDepartment,
       Club.ClubName,
       Club.ClubID

--Total Non-Corporate Internal transaction data - All Departments
INSERT INTO #ReportingData

SELECT CASE WHEN Club.ValPresaleID = 1 THEN 'Open Clubs'
            WHEN Club.ValPresaleID = 4 THEN 'Not Open For PreSale'
            ELSE 'PreSale Clubs'
         END ClubStatus,
       CASE WHEN Club.ClubID = 9999 THEN
            CASE WHEN TranItemClub.ClubID IS NULL THEN ValPTRCLArea.Description
                 ELSE TranItemValPTRCLArea.Description END
            ELSE ValPTRCLArea.Description
       END AS Region,
       CASE WHEN Club.ClubID = 9999 THEN                                            
            CASE WHEN TranItemClub.ClubID IS NULL THEN Club.ClubCode               
                 ELSE TranItemClub.ClubCode END                                    
            ELSE Club.ClubCode                                                     
       END AS ClubCode,   
       'Total' as RevenueReportingDepartment,
       Sum(TranItem.ItemAmount) ActualRevenue,
       @HeaderDateRange HeaderDateRange,
 
       CASE WHEN Club.ClubID = 9999 THEN                                            
            CASE WHEN TranItemClub.ClubID IS NULL THEN Club.ClubName               
                 ELSE TranItemClub.ClubName END                                    
            ELSE Club.ClubName                                                     
       END AS ClubName,  
       CASE WHEN Club.ClubID = 9999 THEN                                            
            CASE WHEN TranItemClub.ClubID IS NULL THEN Club.ClubID               
                 ELSE TranItemClub.ClubID END                                    
            ELSE Club.ClubID
       END AS ClubID,  
       1 as SortOrder
FROM vMMSTran MMSTran
JOIN vClub Club
  ON MMSTran.ClubID = Club.ClubID
JOIN vTranItem TranItem
  ON MMSTran.MMSTranID = TranItem.MMSTranID
LEFT JOIN vClub TranItemClub
  ON TranItem.ClubID = TranItemClub.ClubID
LEFT JOIN vValPTRCLArea TranItemValPTRCLArea
  ON TranItemValPTRCLArea.ValPTRCLAreaID = Club.ValPTRCLAreaID
JOIN vProduct Product
  ON Product.ProductID = TranItem.ProductID
JOIN vProductGroup ProductGroup
  ON Product.ProductID = ProductGroup.ProductID
JOIN vValProductGroup ValProductGroup
  ON ProductGroup.ValProductGroupID = ValProductGroup.ValProductGroupID
JOIN vValPTRCLArea ValPTRCLArea
  ON ValPTRCLArea.ValPTRCLAreaID = Club.ValPTRCLAreaID
JOIN #tmpList
  ON #tmpList.StringField = ValProductGroup.RevenueReportingDepartment
LEFT JOIN vMMSTranRefund MMSTranRefund
  ON MMSTran.MMSTranID = MMSTranRefund.MMSTranID
WHERE MMSTran.PostDateTime >= @StartPostDate
  AND MMSTran.PostDateTime < @AdjustedEndPostDate
  AND MMSTran.TranVoidedID is NULL
  AND MMSTran.ValTranTypeID in (1,3,4,5)
  AND MMSTranRefund.MMSTranRefundID is NULL
  AND Club.ClubID not in (13)
GROUP BY CASE WHEN Club.ValPresaleID = 1 THEN 'Open Clubs'
              WHEN Club.ValPresaleID = 4 THEN 'Not Open For PreSale'
              ELSE 'PreSale Clubs'
           END,
       CASE WHEN Club.ClubID = 9999 THEN
            CASE WHEN TranItemClub.ClubID IS NULL THEN ValPTRCLArea.Description
                 ELSE TranItemValPTRCLArea.Description END
            ELSE ValPTRCLArea.Description END,
       CASE WHEN Club.ClubID = 9999 THEN                                            
            CASE WHEN TranItemClub.ClubID IS NULL THEN Club.ClubCode               
                 ELSE TranItemClub.ClubCode END                                    
            ELSE Club.ClubCode END,
       ValProductGroup.RevenueReportingDepartment,
       CASE WHEN Club.ClubID = 9999 THEN                                            
            CASE WHEN TranItemClub.ClubID IS NULL THEN Club.ClubName               
                 ELSE TranItemClub.ClubName END                                    
            ELSE Club.ClubName END,
       CASE WHEN Club.ClubID = 9999 THEN                                            
            CASE WHEN TranItemClub.ClubID IS NULL THEN Club.ClubID               
                 ELSE TranItemClub.ClubID END                                    
            ELSE Club.ClubID END 

--Total Corporate Internal transaction data - All Departments
INSERT INTO #ReportingData

SELECT CASE WHEN Club.ValPresaleID = 1 THEN 'Open Clubs'
            WHEN Club.ValPresaleID = 4 THEN 'Not Open For PreSale'
            ELSE 'PreSale Clubs'
         END ClubStatus,
       ValPTRCLArea.Description Region,
       Club.ClubCode,
       'Total' as RevenueReportingDepartment,
       Sum(TranItem.ItemAmount) ActualRevenue,
       @HeaderDateRange HeaderDateRange,
       Club.ClubName,
       Club.ClubID,
       1 as SortOrder
FROM vMMSTran MMSTran
JOIN vTranItem TranItem
  ON MMSTran.MMSTranID = TranItem.MMSTranID
JOIN vProduct Product
  ON Product.ProductID = TranItem.ProductID
JOIN vProductGroup ProductGroup
  ON Product.ProductID = ProductGroup.ProductID
JOIN vValProductGroup ValProductGroup
  ON ProductGroup.ValProductGroupID = ValProductGroup.ValProductGroupID
JOIN vMembership Membership
  ON MMSTran.MembershipID = Membership.MembershipID
JOIN vClub Club
  ON Membership.ClubID = Club.ClubID
JOIN vValPTRCLArea ValPTRCLArea
  ON ValPTRCLArea.ValPTRCLAreaID = Club.ValPTRCLAreaID
JOIN #tmpList
  ON #tmpList.StringField = ValProductGroup.RevenueReportingDepartment
LEFT JOIN vMMSTranRefund MMSTranRefund
  ON MMSTran.MMSTranID = MMSTranRefund.MMSTranID
WHERE MMSTran.PostDateTime >= @StartPostDate
  AND MMSTran.PostDateTime < @AdjustedEndPostDate
  AND MMSTran.TranVoidedID is NULL
  AND MMSTran.ValTranTypeID in (1,3,4,5)
  AND MMSTranRefund.MMSTranRefundID is NULL
  AND Club.ClubID in (13)
GROUP BY CASE WHEN Club.ValPresaleID = 1 THEN 'Open Clubs'
              WHEN Club.ValPresaleID = 4 THEN 'Not Open For PreSale'
              ELSE 'PreSale Clubs'
           END,
       ValPTRCLArea.Description,
       Club.ClubCode,
       ValProductGroup.RevenueReportingDepartment,
       Club.ClubName,
       Club.ClubID

--Total Automated Refunds - All Departments
INSERT INTO #ReportingData

SELECT CASE WHEN Club.ValPresaleID = 1 THEN 'Open Clubs'
            WHEN Club.ValPresaleID = 4 THEN 'Not Open For PreSale'
            ELSE 'PreSale Clubs'
         END ClubStatus,
       ValPTRCLArea.Description Region,
       Club.ClubCode,
       'Total' as RevenueReportingDepartment,
       Sum(TranItem.ItemAmount) ActualRevenue,
       @HeaderDateRange HeaderDateRange,
       Club.ClubName,
       Club.ClubID,
       1 as SortOrder
FROM vMMSTran MMSTran
JOIN #ReportRefunds
  ON #ReportRefunds.RefundMMSTranID = MMSTran.MMSTranID
JOIN vTranItem TranItem
  ON MMSTran.MMSTranID = TranItem.MMSTranID
JOIN vProduct Product
  ON Product.ProductID = TranItem.ProductID
JOIN vProductGroup ProductGroup
  ON Product.ProductID = ProductGroup.ProductID
JOIN vValProductGroup ValProductGroup
  ON ProductGroup.ValProductGroupID = ValProductGroup.ValProductGroupID
JOIN vClub Club
  ON #ReportRefunds.PostingMMSClubID = Club.ClubID
JOIN vValPTRCLArea ValPTRCLArea
  ON ValPTRCLArea.ValPTRCLAreaID = Club.ValPTRCLAreaID
JOIN #tmpList
  ON #tmpList.StringField = ValProductGroup.RevenueReportingDepartment
GROUP BY CASE WHEN Club.ValPresaleID = 1 THEN 'Open Clubs'
              WHEN Club.ValPresaleID = 4 THEN 'Not Open For PreSale'
              ELSE 'PreSale Clubs'
           END,
       ValPTRCLArea.Description,
       Club.ClubCode,
       ValProductGroup.RevenueReportingDepartment,
       Club.ClubName,
       Club.ClubID

DROP TABLE #RefundTranIDs
DROP TABLE #ReportRefunds
END

--Result Set
SELECT 
  ClubStatus,
  Region,
  ClubCode,
  RevenueReportingDepartment,
  SUM(ActualRevenue) as ActualRevenue,
  HeaderDateRange,
  ClubName,
  MMSClubID,
  SortOrder
FROM #ReportingData
GROUP BY ClubStatus, Region,ClubCode,RevenueReportingDepartment,HeaderDateRange,ClubName,MMSClubID, SortOrder



DROP TABLE #ReportingData
DROP TABLE #tmpList

END
