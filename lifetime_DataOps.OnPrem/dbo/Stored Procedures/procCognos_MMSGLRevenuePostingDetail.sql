



CREATE PROC [dbo].[procCognos_MMSGLRevenuePostingDetail](
   @StartFourDigitYearDashTwoDigitMonth VARCHAR(7), 
   @MMSDepartmentList VARCHAR(4000), 
   @MMSClubIDList VARCHAR(4000),
   @GLAccountNumberList VARCHAR(8000))
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- This procedure will retrieve from MMSGLRevenuePostingSummary data for Revenue reports
--
--  exec procCognos_MMSGLRevenuePostingDetail '2014-11','Personal Training','2','4610'


/******* Amounts returned are in LocalCurrencyCode ******/

DECLARE @StartDate DATETIME,
        @EndDate DATETIME,
        @ReportRunDateTime VARCHAR(21)

SET @StartDate = Convert(Datetime,SUBSTRING(@StartFourDigitYearDashTwoDigitMonth,6,2)+'-01-'+SUBSTRING(@StartFourDigitYearDashTwoDigitMonth,1,4))
SET @EndDate = DATEADD(MM,1,@StartDate)
SET @ReportRunDateTime = Replace(Substring(convert(varchar, GetDate(), 100),1,6)+', '+Substring(convert(varchar, GetDate(), 100),8,10)+' '+Substring(convert(varchar,GetDate(), 100),18,2),'  ',' ')

CREATE TABLE #tmpList(StringField VARCHAR(50))
EXEC procParseStringList @MMSDepartmentList

SELECT D.DepartmentID, D.Description
  INTO #DepartmentIDList
  FROM #tmpList
  JOIN vDepartment D
    ON #tmpList.StringField = D.Description

TRUNCATE TABLE #tmpList
EXEC procParseStringList @MMSClubIDList

SELECT Convert(INT,#tmpList.StringField) MMSClubID
  INTO #MMSClubIDList
  FROM #tmpList

TRUNCATE TABLE #tmpList
EXEC procParseStringList @GLAccountNumberList

SELECT #tmpList.StringField GLAccountNumber
  INTO #GLAccountNumberList
  FROM #tmpList


SELECT MMSRegion,
       ClubName,
       MMSClubCode,
       Cast(LocalCurrencyItemAmount as Decimal(16,6)) LocalCurrencyItemAmount,
       Cast(USDItemAmount as Decimal(16,6)) USDItemAmount,
       Cast(LocalCurrencyItemDiscountAmount as Decimal(16,6)) LocalCurrencyItemDiscountAmount,
       Cast(USDItemDiscountAmount as Decimal(16,6)) USDItemDiscountAmount,
       Cast(LocalCurrencyGLPostingAmount as Decimal(16,6)) LocalCurrencyGLPostingAmount,
       Cast(USDGLPostingAmount as Decimal(16,6)) USDGLPostingAmount,
       DeptDescription,
       ProductDescription,
       MembershipClubName,
       DrawerActivityID,
       PostDateTime,
       TranDate,
       ValTranTypeID,
       MemberID,
       Cast(LocalCurrencyItemSalesTax as Decimal(16,6)) LocalCurrencyItemSalesTax,
       Cast(USDItemSalesTax as Decimal(16,6)) USDItemSalesTax,
       EmployeeID,
       MemberFirstName,
       MemberLastName,
       TranItemId,
       TranMemberJoinDate,
       MembershipActivationDate,
       MembershipID,
       MMSRevenueGLPostingSummary.ValGLGroupID,
       MMSRevenueGLPostingSummary.GLAccountNumber,
       MMSRevenueGLPostingSummary.GLSubAccountNumber,
       MMSRevenueGLPostingSummary.GLOverRideClubID,
       MMSRevenueGLPostingSummary.ProductID,
       GLGroupIDDescription,
       GLTaxID,
       Posting_GLClubID,
       Posting_RegionDescription,
       Posting_ClubName,
       Posting_MMSClubID,
       CurrencyCode,
       MonthlyAverageExchangeRate,
       EmployeeFirstName,
       EmployeeLastName,
       TransactionDescrption,
       TranTypeDescription,
       Reconciliation_Adj_ValGroupID_Desc,
       Cast(LocalCurrencyReconciliation_Sales as Decimal(16,6)) LocalCurrencyReconciliation_Sales,
       Cast(USDReconciliation_Sales as Decimal(16,6)) USDReconciliation_Sales,
       Cast(LocalCurrencyReconciliation_Adjustment as Decimal(16,6)) LocalCurrencyReconciliation_Adjustment,
       Cast(USDReconciliation_Adjustment as Decimal(16,6)) USDReconciliation_Adjustment,
       Cast(LocalCurrencyReconciliation_Refund as Decimal(16,6)) LocalCurrencyReconciliation_Refund,
       Cast(USDReconciliation_Refund as Decimal(16,6)) USDReconciliation_Refund,
       Cast(LocalCurrencyReconciliation_DuesAssessCharge as Decimal(16,6)) LocalCurrencyReconciliation_DuesAssessCharge,
       Cast(USDReconciliation_DuesAssessCharge as Decimal(16,6)) USDReconciliation_DuesAssessCharge,
       Cast(LocalCurrencyReconciliation_AllOtherCharges as Decimal(16,6)) LocalCurrencyReconciliation_AllOtherCharges,
       Cast(USDReconciliation_AllOtherCharges as Decimal(16,6)) USDReconciliation_AllOtherCharges,
       Reconciliation_ReportMonthYear,
       Reconciliation_Posting_Sub_Account,
       Reconciliation_ReportHeader_TranType,
       Reconciliation_ReportLineGrouping,
       Reconciliation_Adj_GLAccountNumber,
       PostingInstruction,
       @ReportRunDateTime ReportRunDateTime,
       @StartFourDigitYearDashTwoDigitMonth HeaderYearMonth,
       Cast('' as Varchar(80)) HeaderEmptyResult,
       ItemQuantity,
       MMSRevenueGLPostingSummary.WorkdayAccount,
       MMSRevenueGLPostingSummary.WorkdayCostCenter,
       MMSRevenueGLPostingSummary.WorkdayOffering,
       MMSRevenueGLPostingSummary.WorkdayRegion,
       MMSRevenueGLPostingSummary.WorkdayOverRideRegion,
       MMSRevenueGLPostingSummary.DeferredRevenueFlag,
       Reconciliation_Adj_WorkdayAccount,
       Reconciliation_PostingWorkdayRegion,
       Reconciliation_PostingWorkdayCostCenter,
       Reconciliation_PostingWorkdayOffering,
       Reconciliation_WorkdayReportLineGrouping,
       MMSRevenueGLPostingSummary.RevenueCategory,
       MMSRevenueGLPostingSummary.SpendCategory,
       MMSRevenueGLPostingSummary.PayComponent,
	   CASE WHEN IsNull(P.PackageProductFlag,0) = 1
	        THEN 'Yes'
			ELSE 'No'
			END PackagedProduct
  INTO #Results
  FROM MMSRevenueGLPostingSummary
  JOIN #DepartmentIDList
    ON MMSRevenueGLPostingSummary.DepartmentID = #DepartmentIDList.DepartmentID
  JOIN #MMSClubIDList
    ON MMSRevenueGLPostingSummary.Posting_MMSClubID = #MMSClubIDList.MMSClubID 
  LEFT JOIN vProduct P
    ON  MMSRevenueGLPostingSummary.ProductID = P.ProductID
  LEFT JOIN #GLAccountNumberList GLAList1
    ON MMSRevenueGLPostingSummary.Reconciliation_Adj_GLAccountNumber = GLAList1.GLAccountNumber
  LEFT JOIN #GLAccountNumberList GLAList2
    ON MMSRevenueGLPostingSummary.Reconciliation_Adj_WorkdayAccount = GLAList2.GLAccountNumber
 WHERE Convert(Datetime,PostDateTime) >= Convert(Datetime,@StartDate)
   AND Convert(Datetime,PostDateTime) < Convert(Datetime,@EndDate)
   AND (GLAList1.GLAccountNumber IS NOT NULL OR GLAList2.GLAccountNumber IS NOT NULL)

SELECT * 
  FROM  #Results 
 WHERE (SELECT COUNT(*) FROM #Results) > 0
UNION ALL
SELECT Cast(NULL AS Varchar(50)) MMSRegion,
       Cast(NULL AS Varchar(50)) ClubName,
       Cast(NULL AS Varchar(3)) MMSClubCode,
       Cast(NULL AS Decimal(16,6)) LocalCurrencyItemAmount,
       Cast(NULL AS Decimal(16,6)) USDItemAmount,
       Cast(NULL AS Decimal(16,6)) LocalCurrencyItemDiscountAmount,
       Cast(NULL AS Decimal(16,6)) USDItemDiscountAmount,
       Cast(NULL AS Decimal(16,6)) LocalCurrencyGLPostingAmount,
       Cast(NULL AS Decimal(16,6)) USDGLPostingAmount,
       Cast(NULL AS Varchar(50)) DeptDescription,
       Cast(NULL AS Varchar(50)) ProductDescription,
       Cast(NULL AS Varchar(50)) MembershipClubName,
       Cast(NULL AS INT) DrawerActivityID,
       Cast(NULL AS DATETIME) PostDateTime,
       Cast(NULL AS DATETIME) TranDate,
       Cast(NULL AS INT) ValTranTypeID,
       Cast(NULL AS INT) MemberID,
       Cast(NULL AS Decimal(16,6)) LocalCurrencyItemSalesTax,
       Cast(NULL AS Decimal(16,6)) USDItemSalesTax,
       Cast(NULL AS INT) EmployeeID,
       Cast(NULL AS Varchar(50)) MemberFirstName,
       Cast(NULL AS Varchar(50)) MemberLastName,
       Cast(NULL AS INT) TranItemId,
       Cast(NULL AS DATETIME) TranMemberJoinDate,
       Cast(NULL AS DATETIME) MembershipActivationDate,
       Cast(NULL AS INT) MembershipID,
       Cast(NULL AS INT) ValGLGroupID,
       Cast(NULL AS Varchar(10)) GLAccountNumber,
       Cast(NULL AS Varchar(10)) GLSubAccountNumber,
       Cast(NULL AS INT) GLOverRideClubID,
       Cast(NULL AS INT) ProductID,
       Cast(NULL AS Varchar(50)) GLGroupIDDescription,
       Cast(NULL AS INT) GLTaxID,
       Cast(NULL AS INT) Posting_GLClubID,
       Cast(NULL AS Varchar(50)) Posting_RegionDescription,
       Cast(NULL AS Varchar(50)) Posting_ClubName,
       Cast(NULL AS INT) Posting_MMSClubID,
       Cast(NULL AS Varchar(3)) CurrencyCode,
       Cast(NULL AS Decimal(14,4)) MonthlyAverageExchangeRate,
       Cast(NULL AS Varchar(50)) EmployeeFirstName,
       Cast(NULL AS Varchar(50)) EmployeeLastName,
       Cast(NULL AS Varchar(50)) TransactionDescrption,
       Cast(NULL AS Varchar(50)) TranTypeDescription,
       Cast(NULL AS Varchar(8000)) Reconciliation_Adj_ValGroupID_Desc,
       Cast(NULL AS Varchar(50)) LocalCurrencyReconciliation_Sales,
       Cast(NULL AS Varchar(50)) USDReconciliation_Sales,
       Cast(NULL AS Varchar(50)) LocalCurrencyReconciliation_Adjustment,
       Cast(NULL AS Varchar(50)) USDReconciliation_Adjustment,
       Cast(NULL AS Varchar(50)) LocalCurrencyReconciliation_Refund,
       Cast(NULL AS Varchar(50)) USDReconciliation_Refund,
       Cast(NULL AS Varchar(50)) LocalCurrencyReconciliation_DuesAssessCharge,
       Cast(NULL AS Varchar(50)) USDReconciliation_DuesAssessCharge,
       Cast(NULL AS Varchar(50)) LocalCurrencyReconciliation_AllOtherCharges,
       Cast(NULL AS Varchar(50)) USDReconciliation_AllOtherCharges,
       Cast(NULL AS Varchar(20)) Reconciliation_ReportMonthYear,
       Cast(NULL AS Varchar(20)) Reconciliation_Posting_Sub_Account,
       Cast(NULL AS Varchar(50)) Reconciliation_ReportHeader_TranType,
       Cast(NULL AS Varchar(8000)) Reconciliation_ReportLineGrouping,
       Cast(NULL AS Varchar(10)) Reconciliation_Adj_GLAccountNumber,
       Cast(NULL AS Varchar(102)) PostingInstruction,
       @ReportRunDateTime ReportRunDateTime,
       @StartFourDigitYearDashTwoDigitMonth HeaderYearMonth,
       'There are no transactions available for the selected parameters.  Please re-try.' HeaderEmptyResult,
       CAST(NULL as INT) ItemQuantity,
       CAST(NULL as VARCHAR(10)) WorkdayAccount,
       CAST(NULL as VARCHAR(6)) WorkdayCostCenter,
       CAST(NULL as VARCHAR(10)) WorkdayOffering,
       CAST(NULL as VARCHAR(4)) WorkdayRegion,
       CAST(NULL as VARCHAR(4)) WorkdayOverRideRegion,
       CAST(NULL as CHAR(1)) DeferredRevenueFlag,
       CAST(NULL as VARCHAR(10)) Reconciliation_Adj_WorkdayAccount,
       CAST(NULL as VARCHAR(4)) Reconciliation_PostingWorkdayRegion,
       CAST(NULL as VARCHAR(6)) Reconciliation_PostingWorkdayCostCenter,
       CAST(NULL as VARCHAR(10)) Reconciliation_PostingWorkdayOffering,
       CAST(NULL as VARCHAR(226)) Reconciliation_WorkdayReportLineGrouping,
       CAST(NULL as VARCHAR(7)) RevenueCategory,
       CAST(NULL as VARCHAR(7)) SpendCategory,
       CAST(NULL as VARCHAR(50)) PayComponent,
	   CAST(NULL as VARCHAR(7)) PackagedProduct
 WHERE (SELECT COUNT(*) 
          FROM #Results) = 0

DROP TABLE #tmpList
DROP TABLE #DepartmentIDList
DROP TABLE #MMSClubIDList
DROP TABLE #GLAccountNumberList

END




