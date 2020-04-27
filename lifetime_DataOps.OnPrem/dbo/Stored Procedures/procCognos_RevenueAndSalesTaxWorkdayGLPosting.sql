






CREATE PROC [dbo].[procCognos_RevenueAndSalesTaxWorkdayGLPosting] (
  @MMSClubIDList Varchar(1000),
  @TransactionPostMonth Datetime
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

SELECT Item StringField
  INTO #tmpList
  FROM fnParsePipeList(@MMSClubIDList)

DECLARE @PostDateStart DATETIME
DECLARE @PostDateEND DATETIME
DECLARE @FirstOfMonth DATETIME
DECLARE @ReportRunDateTime VARCHAR(21)
	
SET @FirstOfMonth  =  CONVERT(DATETIME, SUBSTRING(CONVERT(VARCHAR,dateadd(mm,0,@TransactionPostMonth),112),1,6) + '01', 112)
SET @PostDateStart  =  DATEADD(mm,DATEDIFF(mm,0,@firstofmonth),0)
SET @PostDateEnd  =  DATEADD(mm,DATEDIFF(mm,0,DATEADD(mm,1,@firstofmonth)),0)
SET @ReportRunDateTime = Replace(Substring(convert(varchar,getdate(),100),1,6)+', '+Substring(convert(varchar,getdate(),100),8,10)+' '+Substring(convert(varchar,getdate(),100),18,2),'  ',' ')

SELECT TranItemId,
       Posting_RegionDescription MMSRegionName,
       Posting_ClubName ClubName,
       MMSClubCode ClubCode,
       Posting_MMSClubID,
       Reconciliation_PostingWorkdayRegion WorkdayRegion,
       Reconciliation_Adj_ValGroupID_Desc,--posting description
       Reconciliation_Adj_WorkdayAccount WorkdayAccount,
       Reconciliation_PostingWorkdayCostCenter WorkdayCostCenter,
       Reconciliation_PostingWorkdayOffering WorkdayOffering,
       Reconciliation_ReportMonthYear,
       Reconciliation_WorkdayReportLineGrouping,
       LocalCurrencyGLPostingAmount GLPostingAmount,
       LocalCurrencyItemSalesTax ItemSalesTax,
       PostingInstruction,
---Embedded calcs
       Posting_RegionDescription + ' Region - ' + Posting_ClubName Region_Club,
       CAST(0 as Money) Accum_AdjSalesTax,
       Cast(0 as Decimal(12,2)) AS Accum_GLPostingAmount,
       CASE WHEN Reconciliation_Adj_ValGroupID_Desc = 'Next Month Dues'
	             THEN 1
			WHEN MMSRevenueGLPostingSummary.ProductID = 1497 AND CASE WHEN DrawerActivityID > 0 AND Employeeid < 0 AND Valtrantypeid = 1 THEN LocalCurrencyItemAmount ELSE 0 END = 0
                 THEN 2
            WHEN MMSRevenueGLPostingSummary.ValGLGroupID = 12
                 THEN 998
            WHEN MMSRevenueGLPostingSummary.ValGLGroupID = 13
                 THEN 999
            WHEN MMSRevenueGLPostingSummary.ValGLGroupID = 1 AND CASE WHEN DrawerActivityID > 0 AND Employeeid < 0 AND Valtrantypeid = 1 THEN LocalCurrencyItemAmount ELSE 0 END = 0
                 THEN 2
            ELSE MMSRevenueGLPostingSummary.ValGLGroupID END AS SortValGroupID,
       MMSRevenueGLPostingSummary.DeferredRevenueFlag,
       IsNull(MMSRevenueGLPostingSummary.RevenueCategory,'') AS RevenueCategory,
       IsNull(MMSRevenueGLPostingSummary.SpendCategory,'') AS SpendCategory,
       IsNull(MMSRevenueGLPostingSummary.PayComponent,'') AS PayComponent,
	   CASE WHEN IsNull(Product.PackageProductFlag,0) = 1
	        THEN 'Yes'
			ELSE 'No'
			END PackagedProduct
  INTO #Results       
  FROM MMSRevenueGLPostingSummary
  Left Join vProduct Product
    On MMSRevenueGLPostingSummary.ProductID = Product.ProductID
 WHERE PostDateTime >= @PostDateStart
   AND PostDateTime <= @PostDateEND
   AND Convert(Varchar,Posting_MMSClubID) IN (SELECT StringField FROM #tmpList)

UPDATE #Results
   SET Accum_AdjSalesTax = T.Adj_ItemSalesTax
  FROM #Results
  JOIN (SELECT WorkdayRegion,Region_Club,RevenueCategory,SpendCategory,PayComponent, Sum(ItemSalesTax) Adj_ItemSalesTax FROM #Results WHERE PostingInstruction = 'Positive = Credit Entry and Negative = Debit Entry' GROUP BY WorkdayRegion, Region_Club,RevenueCategory,SpendCategory,PayComponent) T
    ON #Results.Region_Club = T.Region_Club
    AND #Results.WorkdayRegion = T.WorkdayRegion
    AND #Results.RevenueCategory = T.RevenueCategory
    AND #Results.SpendCategory = T.SpendCategory
    AND #Results.PayComponent = T.PayComponent

UPDATE Results
   SET Results.Accum_GLPostingAmount = T.GLPostingAmount
  FROM #Results Results
  JOIN (SELECT Reconciliation_WorkdayReportLineGrouping, Posting_MMSClubID,WorkdayRegion,RevenueCategory,SpendCategory,PayComponent, Sum(GLPostingAmount) GLPostingAmount,PackagedProduct FROM #Results GROUP BY Reconciliation_WorkdayReportLineGrouping, Posting_MMSClubID,WorkdayRegion,RevenueCategory,SpendCategory,PayComponent,PackagedProduct) T
    ON Results.Reconciliation_WorkdayReportLineGrouping = T.Reconciliation_WorkdayReportLineGrouping
    AND Results.WorkdayRegion = T.WorkdayRegion
    AND Results.RevenueCategory = T.RevenueCategory
    AND Results.SpendCategory = T.SpendCategory
    AND Results.PayComponent = T.PayComponent  
  WHERE Results.Posting_MMSClubID = T.Posting_MMSClubID 
    AND Results.PackagedProduct = T.PackagedProduct


SELECT #Results.MMSRegionName,
       #Results.ClubName,
       #Results.ClubCode,
       #Results.WorkdayRegion,
       #Results.Reconciliation_Adj_ValGroupID_Desc AS PostingDescription,
       #Results.WorkdayAccount,
       #Results.WorkdayCostCenter,
       #Results.WorkdayOffering,
       VCC1.CurrencyCode LocalCurrencyCode,
       CASE WHEN Accum_GLPostingAmount >= 0 AND PostingInstruction = 'Positive = Credit Entry and Negative = Debit Entry'
                 THEN Accum_GLPostingAmount 
            WHEN Accum_GLPostingAmount < 0 AND PostingInstruction = 'Positive = Debit Entry and Negative = Credit Entry'
                 THEN ABS(Accum_GLPostingAmount)
            ELSE 0 END LocalCurrencyCreditEntry,
       CASE WHEN Accum_GLPostingAmount < 0 AND PostingInstruction = 'Positive = Credit Entry and Negative = Debit Entry' 
                 THEN ABS(Accum_GLPostingAmount) 
            WHEN Accum_GLPostingAmount >= 0 AND PostingInstruction = 'Positive = Debit Entry and Negative = Credit Entry'
                 THEN Accum_GLPostingAmount
            ELSE 0 END LocalCurrencyDebitEntry, 
       USDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate,
       CASE WHEN Accum_GLPostingAmount >= 0 AND PostingInstruction = 'Positive = Credit Entry and Negative = Debit Entry'
                 THEN Accum_GLPostingAmount * USDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate
            WHEN Accum_GLPostingAmount < 0 AND PostingInstruction = 'Positive = Debit Entry and Negative = Credit Entry'
                 THEN ABS(Accum_GLPostingAmount) * USDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate
            ELSE Cast(0  as Decimal(16,6)) END USDCreditEntry,
       CASE WHEN Accum_GLPostingAmount < 0 AND PostingInstruction = 'Positive = Credit Entry and Negative = Debit Entry' 
                 THEN ABS(Accum_GLPostingAmount) * USDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate
            WHEN Accum_GLPostingAmount >= 0 AND PostingInstruction = 'Positive = Debit Entry and Negative = Credit Entry'
                 THEN Accum_GLPostingAmount * USDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate
            ELSE Cast(0  as Decimal(16,6)) END USDDebitEntry, 
       Reconciliation_ReportMonthYear AS ReportMonthYear,
       DeferredRevenueFlag,
       SortValGroupID AS PostingSortGroup,
       @ReportRunDateTime ReportRunDateTime,
       #Results.RevenueCategory,
       #Results.SpendCategory,
       #Results.PayComponent,
	   #Results.PackagedProduct
  FROM #Results
  JOIN vClub C1 
    ON C1.ClubID = #Results.Posting_MMSClubID
  JOIN vValCurrencyCode VCC1 
    ON C1.ValCurrencyCodeID = VCC1.ValCurrencyCodeID
  JOIN vMonthlyAverageExchangeRate USDMonthlyAverageExchangeRate
    ON VCC1.CurrencyCode = USDMonthlyAverageExchangeRate.FromCurrencyCode
   AND 'USD' = USDMonthlyAverageExchangeRate.ToCurrencyCode
   AND @FirstOfMonth = USDMonthlyAverageExchangeRate.FirstOfMonthDate
 WHERE ABS(Accum_GLPostingAmount) > 0

UNION

SELECT #Results.MMSRegionName,
       #Results.ClubName,
       #Results.ClubCode,
       #Results.WorkdayRegion,
       'Sales Tax' AS PostingDescription,
       '211030' WorkdayAccount,
       '',--#Results.WorkdayCostCenter,
       '',--#Results.WorkdayOffering,
       VCC1.CurrencyCode LocalCurrencyCode,
       CASE WHEN Accum_AdjSalesTax >= 0 THEN Accum_AdjSalesTax ELSE 0 END AS LocalCurrencyCreditEntry, 
       CASE WHEN Accum_AdjSalesTax < 0 THEN ABS(Accum_AdjSalesTax) ELSE 0 END AS LocalCurrencyDebitEntry,
       USDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate,
       CASE WHEN Accum_AdjSalesTax >= 0 THEN Accum_AdjSalesTax * USDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate ELSE 0 END AS USDCreditEntry, 
       CASE WHEN Accum_AdjSalesTax < 0 THEN ABS(Accum_AdjSalesTax) * USDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate ELSE 0 END AS USDDebitEntry,
       Reconciliation_ReportMonthYear AS ReportMonthYear,
       'N',--DeferredRevenueFlag,
       1000 AS PostingSortGroup,
       @ReportRunDateTime ReportRunDateTime,
       '' as RevenueCategory,
       #Results.SpendCategory,
       #Results.PayComponent,
	   'No' as PackagedProduct
  FROM #Results
  JOIN vClub C1
    ON #Results.Posting_MMSClubID = C1.ClubID
  JOIN vValCurrencyCode VCC1
    ON C1.ValCurrencyCodeID = VCC1.ValCurrencyCodeID
  JOIN vMonthlyAverageExchangeRate USDMonthlyAverageExchangeRate
    ON VCC1.CurrencyCode = USDMonthlyAverageExchangeRate.FromCurrencyCode
   AND 'USD' = USDMonthlyAverageExchangeRate.ToCurrencyCode
   AND @FirstOfMonth = USDMonthlyAverageExchangeRate.FirstOfMonthDate
 WHERE ABS(Accum_AdjSalesTax) > 0
 GROUP BY #Results.MMSRegionName,
          #Results.ClubName,
          #Results.ClubCode,
          #Results.WorkdayRegion,
          --#Results.WorkdayCostCenter,
          --#Results.WorkdayOffering,
          VCC1.CurrencyCode,
          CASE WHEN Accum_AdjSalesTax >= 0 THEN Accum_AdjSalesTax ELSE 0 END, 
          CASE WHEN Accum_AdjSalesTax < 0 THEN ABS(Accum_AdjSalesTax) ELSE 0 END,
          USDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate,
          CASE WHEN Accum_AdjSalesTax >= 0 THEN Accum_AdjSalesTax * USDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate ELSE 0 END, 
          CASE WHEN Accum_AdjSalesTax < 0 THEN ABS(Accum_AdjSalesTax) * USDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate ELSE 0 END,
          Reconciliation_ReportMonthYear,
          --DeferredRevenueFlag
          #Results.RevenueCategory,
          #Results.SpendCategory,
          #Results.PayComponent,
		  #Results.PackagedProduct
 Order by MMSRegionName, ClubName,PostingSortGroup

-- remove temp tables

DROP TABLE #Results
DROP TABLE #tmpList


END






