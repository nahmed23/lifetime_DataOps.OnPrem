


 ---- Sample execution
 ---- exec procCognos_RevenueAndSalesTaxGLPosting_SolomonAndWorkday '151','11/1/2014'


CREATE PROC [dbo].[procCognos_RevenueAndSalesTaxGLPosting_SolomonAndWorkday] (
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

SELECT TranItemID,                                     
       LocalCurrencyGLPostingAmount GLPostingAmount,    
       LocalCurrencyItemSalesTax ItemSalesTax,
       MMSRevenueGLPostingSummary.GLTaxID,
       Posting_GLClubID,
       Posting_RegionDescription as MMSRegionName,
       Posting_ClubName,
       Posting_MMSClubID,
       MMSClubCode Posting_ClubCode,       
       Reconciliation_Adj_ValGroupID_Desc,  
       Reconciliation_ReportMonthYear,
       Reconciliation_Posting_Sub_Account,
       Reconciliation_ReportHeader_TranType,
       Reconciliation_ReportLineGrouping,
       Reconciliation_Adj_GLAccountNumber,
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
        Reconciliation_PostingWorkdayRegion  as WorkdayRegion,
        Reconciliation_Adj_WorkdayAccount as WorkdayAccount,
        Reconciliation_PostingWorkdayCostCenter as WorkdayCostCenter,
        Reconciliation_PostingWorkdayOffering as WorkdayOffering,
        Reconciliation_WorkdayReportLineGrouping,
        MMSRevenueGLPostingSummary.DeferredRevenueFlag,
        IsNull(MMSRevenueGLPostingSummary.RevenueCategory,'') as RevenueCategory,
        IsNull(MMSRevenueGLPostingSummary.SpendCategory,'') as SpendCategory,
        IsNull(MMSRevenueGLPostingSummary.PayComponent,'') as PayComponent,
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
  JOIN (SELECT WorkdayRegion,Region_Club,RevenueCategory, SpendCategory, PayComponent, Sum(ItemSalesTax) Adj_ItemSalesTax 
            FROM #Results 
            WHERE PostingInstruction = 'Positive = Credit Entry and Negative = Debit Entry' 
            GROUP BY WorkdayRegion,Region_Club,RevenueCategory, SpendCategory, PayComponent) T
    ON #Results.Region_Club = T.Region_Club
    AND #Results.WorkdayRegion = T.WorkdayRegion
    AND #Results.RevenueCategory = T.RevenueCategory
    AND #Results.SpendCategory = T.SpendCategory
    AND #Results.PayComponent = T.PayComponent

UPDATE Results
   SET Results.Accum_GLPostingAmount = T.GLPostingAmount
  FROM #Results Results
  JOIN (SELECT Reconciliation_ReportLineGrouping, Posting_MMSClubID,Reconciliation_WorkdayReportLineGrouping, WorkdayRegion, RevenueCategory, SpendCategory, PayComponent, Sum(GLPostingAmount) GLPostingAmount,PackagedProduct 
        FROM #Results 
        GROUP BY Reconciliation_ReportLineGrouping, Posting_MMSClubID,Reconciliation_WorkdayReportLineGrouping, WorkdayRegion, RevenueCategory, SpendCategory, PayComponent,PackagedProduct) T
    ON Results.Reconciliation_ReportLineGrouping = T.Reconciliation_ReportLineGrouping
    AND Results.Reconciliation_WorkdayReportLineGrouping = T.Reconciliation_WorkdayReportLineGrouping
    AND Results.WorkdayRegion = T.WorkdayRegion
    AND Results.RevenueCategory = T.RevenueCategory
    AND Results.SpendCategory = T.SpendCategory
    AND Results.PayComponent = T.PayComponent
  WHERE Results.Posting_MMSClubID = T.Posting_MMSClubID 
    AND Results.PackagedProduct = T.PackagedProduct

SELECT #Results.MMSRegionName,
       #Results.Posting_ClubName,
       #Results.Posting_ClubCode,      
       #Results.Reconciliation_Adj_ValGroupID_Desc AS PostingDescription,
       Reconciliation_Adj_GLAccountNumber AS GLAccountNumber,
       Reconciliation_Posting_Sub_Account AS PostingSubAccount, 
       VCC1.CurrencyCode As LocalCurrencyCode,
       USDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate,
       CASE WHEN Accum_GLPostingAmount >= 0 AND PostingInstruction = 'Positive = Credit Entry and Negative = Debit Entry'
                 THEN Accum_GLPostingAmount 
            WHEN Accum_GLPostingAmount < 0 AND PostingInstruction = 'Positive = Debit Entry and Negative = Credit Entry'
                 THEN ABS(Accum_GLPostingAmount)
            ELSE 0 
       END AS LocalCurrencyCredit_Entry,
       CASE WHEN Accum_GLPostingAmount < 0 AND PostingInstruction = 'Positive = Credit Entry and Negative = Debit Entry' 
                 THEN ABS(Accum_GLPostingAmount) 
            WHEN Accum_GLPostingAmount >= 0 AND PostingInstruction = 'Positive = Debit Entry and Negative = Credit Entry'
                 THEN Accum_GLPostingAmount
            ELSE 0 
       END AS LocalCurrencyDebit_Entry, 
       CASE WHEN Accum_GLPostingAmount >= 0 AND PostingInstruction = 'Positive = Credit Entry and Negative = Debit Entry'
                 THEN Accum_GLPostingAmount * USDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate
            WHEN Accum_GLPostingAmount < 0 AND PostingInstruction = 'Positive = Debit Entry and Negative = Credit Entry'
                 THEN ABS(Accum_GLPostingAmount) * USDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate
            ELSE Cast(0  as Decimal(16,6))
       END AS USDCredit_Entry,
       CASE WHEN Accum_GLPostingAmount < 0 AND PostingInstruction = 'Positive = Credit Entry and Negative = Debit Entry' 
                 THEN ABS(Accum_GLPostingAmount) * USDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate
            WHEN Accum_GLPostingAmount >= 0 AND PostingInstruction = 'Positive = Debit Entry and Negative = Credit Entry'
                 THEN Accum_GLPostingAmount * USDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate
            ELSE Cast(0  as Decimal(16,6)) 
       END AS USDDebit_Entry,
       #Results.WorkdayRegion,
       #Results.WorkdayAccount,
       #Results.WorkdayCostCenter,
       #Results.WorkdayOffering,
       #Results.DeferredRevenueFlag,
       #Results.RevenueCategory,
       #Results.SpendCategory,
       #Results.PayComponent,
       Reconciliation_ReportMonthYear AS ReportMonthYear,
       SortValGroupID AS PostingSortGroup,
       @ReportRunDateTime AS ReportRunDateTime,
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
 WHERE ABS(#Results.Accum_GLPostingAmount) > 0

UNION

SELECT #Results.MMSRegionName,
       #Results.Posting_ClubName,
       #Results.Posting_ClubCode,      
       'Sales Tax' as PostingDescription,
       2130 AS GLAccountNumber,
       Cast(#Results.GLTaxID as Varchar) + '-000-000' as PostingSubAccount, 
       VCC1.CurrencyCode as LocalCurrencyCode,
       USDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate,
       CASE WHEN Accum_AdjSalesTax >= 0 THEN Accum_AdjSalesTax ELSE 0 END AS LocalCurrencyCredit_Entry, 
       CASE WHEN Accum_AdjSalesTax < 0 THEN ABS(Accum_AdjSalesTax) ELSE 0 END AS LocalCurrencyDebit_Entry,
       CASE WHEN Accum_AdjSalesTax >= 0 THEN Accum_AdjSalesTax * USDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate ELSE 0 END AS USDCredit_Entry, 
       CASE WHEN Accum_AdjSalesTax < 0 THEN ABS(Accum_AdjSalesTax) * USDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate ELSE 0 END AS USDDebit_Entry,
       #Results.WorkdayRegion,
       '211030' as WorkdayAccount,
       '' as WorkdayCostCenter,
       '' as WorkdayOffering,
       'N' as DeferredRevenueFlag,
       '' as RevenueCategory,
       #Results.SpendCategory,
       #Results.PayComponent,
       Reconciliation_ReportMonthYear AS ReportMonthYear,
       1000 as PostingSortGroup,
       @ReportRunDateTime ReportRunDateTime,
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
 WHERE ABS(#Results.Accum_AdjSalesTax) > 0
 GROUP BY #Results.MMSRegionName,
          #Results.Posting_ClubName,
          #Results.Posting_ClubCode,
          Cast(#Results.GLTaxID as Varchar) + '-000-000',
          VCC1.CurrencyCode,
          #Results.Reconciliation_ReportMonthYear,
          USDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate,
          CASE WHEN Accum_AdjSalesTax >= 0 THEN Accum_AdjSalesTax ELSE 0 END,
          CASE WHEN Accum_AdjSalesTax < 0 THEN ABS(Accum_AdjSalesTax) ELSE 0 END,
          CASE WHEN Accum_AdjSalesTax >= 0 THEN Accum_AdjSalesTax * USDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate ELSE 0 END,
          CASE WHEN Accum_AdjSalesTax < 0 THEN ABS(Accum_AdjSalesTax) * USDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate ELSE 0 END,
          #Results.WorkdayRegion,
          #Results.WorkdayAccount,
          #Results.WorkdayCostCenter,
          #Results.WorkdayOffering,
          #Results.DeferredRevenueFlag,
          #Results.RevenueCategory,
          #Results.SpendCategory,
          #Results.PayComponent,
          Reconciliation_ReportMonthYear,
		  #Results.PackagedProduct
          
 Order by MMSRegionName, Posting_ClubName,PostingSortGroup

-- remove temp tables

DROP TABLE #Results
DROP TABLE #tmpList

END







