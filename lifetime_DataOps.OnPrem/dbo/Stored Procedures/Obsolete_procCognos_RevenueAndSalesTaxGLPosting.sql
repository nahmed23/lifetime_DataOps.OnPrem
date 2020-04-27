
CREATE PROC [dbo].[Obsolete_procCognos_RevenueAndSalesTaxGLPosting] (
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

--LFF Acquisition changes begin
SELECT Membership.MembershipID,
	   Membership.ClubID
  INTO #Membership
  FROM vMembership Membership WITH (NOLOCK)

 
CREATE INDEX IX_MembershipID ON #Membership(MembershipID)
CREATE INDEX IX_ClubID ON #Membership(ClubID)


SELECT DISTINCT 
       MMSTran.MMSTranID, 
	  CASE WHEN MMSTran.ClubID = 13 THEN Membership.ClubID
		   ELSE MMSTran.ClubID END ClubID,
	   MMSTran.MembershipID, 
	   MMSTran.MemberID, 
	   MMSTran.DrawerActivityID,
       MMSTran.ReasonCodeID, 
       MMSTran.ValTranTypeID,
       MMSTran.PostDateTime, 
       MMSTran.EmployeeID, 
       MMSTran.TranAmount
  INTO #MMSTran
  FROM vMMSTran MMSTran
  JOIN #Membership Membership
    ON MMSTran.MembershipID = Membership.MembershipID
 WHERE MMSTran.PostDateTime >= @PostDateStart
   AND MMSTran.PostDateTime < @PostDateEnd
   AND MMSTran.TranVoidedID is NULL

-- returns data on all unvoided automated refund transactions from closed drawers, 
-- posted in the prior month 
SELECT MMSTR.MMSTranRefundID,
	   MMST.MMSTranID as RefundMMSTranID,
	   MMST.ReasonCodeID as RefundReasonCodeID ,
	   MS.ClubID as MembershipClubID
  INTO #RefundTranIDs      
  FROM vMMSTranRefund MMSTR
  JOIN #MMSTran MMST ON MMST.MMSTranID = MMSTR.MMSTranID
  JOIN #Membership MS ON MS.MembershipID = MMST.MembershipID
  JOIN vClub C ON C.ClubID = MS.ClubID
  JOIN vDrawerActivity DA ON DA.DrawerActivityID = MMST.DrawerActivityID 
 WHERE DA.ValDrawerStatusID = 3	-- closed drawers only

SELECT DISTINCT MMSTran.MMSTranID, 
	   MMSTran.ClubID,
	   MMSTran.MembershipID, MMSTran.MemberID, MMSTran.DrawerActivityID,
       MMSTran.ReasonCodeID, MMSTran.ValTranTypeID,
       MMSTran.PostDateTime, MMSTran.EmployeeID,
       MMSTran.TranAmount,
       MMSTran.OriginalMMSTranID,
       MMSTran.TranEditedEmployeeID,
       MMSTran.ReverseTranFlag,
	   #RefundTranIDs.RefundReasonCodeID,
	   #RefundTranIDs.MembershipClubID,
	   #RefundTranIDs.RefundMMSTranID
  INTO #MMSTran2
  FROM vMMSTran MMSTran
  JOIN #Membership Membership 
    ON MMSTran.MembershipID = Membership.MembershipID
  JOIN vMMSTranRefundMMSTran MMSTranRefundMMSTran
    ON MMSTranRefundMMSTran.originalMMSTranID = MMSTran.MMSTranID
  JOIN #RefundTranIDs
    ON MMSTranRefundMMSTran.MMSTranRefundID = #RefundTranIDs.MMSTranRefundID
  JOIN #MMSTran 
    ON #RefundTranIDs.RefundMMSTranID = #MMSTran.MMSTranID
  
CREATE INDEX IX_ClubID ON #MMSTran(ClubID)

-- This query returns original MMSTran transaction data and current membership club data gathered in #RefundTranIDs
-- to determine the club where transaction will be assigned
SELECT MMST.RefundMMSTranID,
       CASE WHEN MMST.RefundReasonCodeID = 108 or MMST.ClubID in(13)
                 THEN MMST.MembershipClubID 
            ELSE MMST.ClubID END AS PostingMMSClubID
  INTO #ReportRefunds
  FROM #MMSTran2 MMST
  JOIN vTranItem TI ON MMST.MMSTranID = TI.MMSTranID

CREATE TABLE #RevenueGLPosting(      
       ItemAmount Money,
       ProductDescription Varchar(50),
       PostDateTime DATETIME,
       ItemSalesTax MONEY,
       ValGLGroupID INT,
       GLAccountNumber VARCHAR(10),
       GLSubAccountNumber VARCHAR(10),
       ProductID INT,
       GLGroupIDDescription VARCHAR(50),
       GLTaxID INT,
       Posting_GLClubID INT,
       Posting_RegionDescription VARCHAR(50),
       Posting_ClubName VARCHAR(50),
       Posting_ClubCode Varchar(5),                
       Posting_MMSClubID INT,
       TransactionDescription VARCHAR(50),
       TranTypeDescription VARCHAR(50),
       Reconciliation_ReportMonthYear VARCHAR(20),
       Reconciliation_Posting_Sub_Account VARCHAR(20),
       Reconciliation_ReportHeader_TranType VARCHAR(50),
       Reconciliation_Adj_GLAccountNumber VARCHAR(10),
       SortValGroupID INT,
       Adj_ValGroupID_Desc VARCHAR(200),
       ItemDiscountAmount Money,             
       DiscountGLAccount VARCHAR(5),
-----Embedded Calcs
       Region_Club VARCHAR(100),
       Accum_AdjSalesTax Decimal(12,2),
       TranItemID INT)

INSERT INTO #RevenueGLPosting

SELECT TI.ItemAmount,
       P.Description ProductDescription, 
       MMST.PostDateTime, 
       TI.ItemSalesTax, 
       P.ValGLGroupID, P.GLAccountNumber, 
       P.GLSubAccountNumber, P.ProductID, 
       VGLG.Description GLGroupIDDescription,
       C1.GLTaxID,
       C1.GLClubID Posting_GLClubID,
       VR.Description Posting_RegionDescription,
       C1.ClubName Posting_ClubName,
       C1.ClubCode Posting_ClubCode,
       C1.ClubID Posting_MMSClubID,
       MMST4.Description TransactionDescription, VTT.Description TranTypeDescription,
       DATENAME(MM, MMST.PostDateTime) + ' ' + DATENAME(YY, MMST.PostDateTime) AS Reconciliation_ReportMonthYear,
       CASE P.GLOverRideClubID
            WHEN 0
                 THEN CAST(C1.GLClubID AS VARCHAR(10)) + '-' + P.GLSubAccountNumber
                 ELSE CAST(P.GLOverRideClubID AS VARCHAR(10)) + '-' + P.GLSubAccountNumber
       END AS Reconciliation_Posting_Sub_Account,
       CASE VTT.Description WHEN 'Automated Refund' THEN 'Refund' ELSE VTT.Description END AS Reconciliation_ReportHeader_TranType,
       '' AS Reconciliation_Adj_GLAccountNumber,
       CASE WHEN P.ProductID = 1497 AND (MMST.Draweractivityid <= 0 OR MMST.Employeeid >= 0 OR MMST.Valtrantypeid != 1) THEN 2
            WHEN P.ValGLGroupID = 12 THEN 998
            WHEN P.ValGLGroupID = 13 THEN 999
            WHEN P.ValGLGroupID = 1 AND (MMST.Draweractivityid <= 0 OR MMST.Employeeid >= 0 OR MMST.Valtrantypeid != 1) THEN 2
            ELSE P.ValGLGroupID END SortValGroupID,
       '' AS Adj_ValGroupID_Desc,
       TI.ItemDiscountAmount,     
       GLA.DiscountGLAccount,
---Embedded calcs
       VR.Description + ' Region - ' + C1.ClubName AS Region_Club,
       Cast(0 as Money) AS Accum_AdjSalesTax,
       TI.TranItemID
  FROM #MMSTran MMST
  LEFT JOIN vMMSTranRefund MMSTR 
	   ON MMSTR.MMSTranID = MMST.MMSTranID
  JOIN dbo.vTranItem TI
       ON TI.MMSTranID = MMST.MMSTranID
  JOIN dbo.vClub C1
       ON C1.ClubID = CASE WHEN MMST.ClubID = 9999 THEN TI.ClubID ELSE MMST.ClubID END
  JOIN dbo.vValRegion VR
       ON C1.ValRegionID = VR.ValRegionID
  JOIN dbo.vProduct P
       ON P.ProductID = TI.ProductID
  JOIN dbo.vValTranType VTT
       ON MMST.ValTranTypeID = VTT.ValTranTypeID
  JOIN dbo.vValGLGroup VGLG
       ON P.ValGLGroupID = VGLG.ValGLGroupID
  JOIN dbo.vReasonCode MMST4
       ON MMST4.ReasonCodeID = MMST.ReasonCodeID
  JOIN dbo.vDrawerActivity DA 
       ON MMST.DrawerActivityID = DA.DrawerActivityID
  LEFT JOIN dbo.vGLAccount GLA  
       ON GLA.RevenueGLAccountNumber = P.GLAccountNumber
 WHERE VTT.Description IN ('Adjustment', 'Charge', 'Sale')
   AND DA.ValDrawerStatusID = 3
   AND MMSTR.MMSTranRefundID is NULL	   -- no automated refunds are returned
   AND MMST.PostDateTime >= @PostDateStart 
   AND MMST.PostDateTime < @PostDateEnd 	-- prior month
   AND CASE WHEN C1.ClubID = 9999 THEN TI.ClubID ELSE C1.ClubID END IN (SELECT StringField FROM #tmpList)

UNION

--Automated Refunds 
SELECT TI.ItemAmount,
       P.Description ProductDescription, 
       MMST.PostDateTime, 
       TI.ItemSalesTax,
       P.ValGLGroupID, GLA.RefundGLAccountNumber AS GLAccountNumber, 
       P.GLSubAccountNumber, P.ProductID, 
       VGLG.Description GLGroupIDDescription, 
	   C.GLTaxID,
	   C.GLClubID Posting_GLClubID,
	   VR.Description Posting_RegionDescription,
	   C.ClubName Posting_ClubName,
	   C.ClubCode Posting_ClubCode,    
       C.ClubID AS Posting_MMSClubid, 
       MMST4.Description TransactionDescription,
	   'Automated Refund' AS TranTypeDescription,
       DATENAME(MM, MMST.PostDateTime) + ' ' + DATENAME(YY, MMST.PostDateTime) AS Reconciliation_ReportMonthYear,
       CASE P.GLOverRideClubID
            WHEN 0
                 THEN CAST(C.GLClubID as VARCHAR(10)) + '-' + P.GLSubAccountNumber
                 ELSE CAST(P.GLOverRideClubID AS VARCHAR(10)) + '-' + P.GLSubAccountNumber
       END AS Reconciliation_Posting_Sub_Account,
       'Refund' AS Reconciliation_ReportHeader_TranType,
---------------------------------------
       '' AS Reconciliation_Adj_GLAccountNumber, -------------,
       CASE WHEN P.ProductID = 1497 AND (MMST.Draweractivityid <= 0 OR MMST.Employeeid >= 0 OR MMST.Valtrantypeid != 1) THEN 2
            WHEN P.ValGLGroupID = 12 THEN 998
            WHEN P.ValGLGroupID = 13 THEN 999
            WHEN P.ValGLGroupID = 1 AND (MMST.Draweractivityid <= 0 OR MMST.Employeeid >= 0 OR MMST.Valtrantypeid != 1) THEN 2
            ELSE P.ValGLGroupID END SortValGroupID,
       '' AS Adj_ValGroupID_Desc,
       TI.ItemDiscountAmount,     
       GLA.DiscountGLAccount,
---Embedded calcs
       VR.Description + ' Region - ' + C.ClubName Region_Club,
       Cast(0 as Money) AS Accum_AdjSalesTax,
       TI.TranItemID
  FROM #MMSTran MMST
  JOIN #ReportRefunds #RR
	   ON #RR.RefundMMSTranID = MMST.MMSTranID
  JOIN dbo.vTranItem TI
       ON TI.MMSTranID = MMST.MMSTranID
  JOIN dbo.vClub C
       ON C.ClubID = CASE WHEN #RR.PostingMMSClubID = 9999 THEN TI.ClubID ELSE #RR.PostingMMSClubID END
  JOIN dbo.vValRegion VR
       ON C.ValRegionID = VR.ValRegionID
  JOIN dbo.vProduct P
       ON P.ProductID = TI.ProductID
  LEFT JOIN vGLAccount GLA                 
	   ON GLA.RevenueGLAccountNumber = P.GLAccountNumber 
  JOIN dbo.vValTranType VTT
       ON MMST.ValTranTypeID = VTT.ValTranTypeID
  JOIN dbo.vValGLGroup VGLG
       ON P.ValGLGroupID = VGLG.ValGLGroupID
  JOIN dbo.vReasonCode MMST4
       ON MMST4.ReasonCodeID = MMST.ReasonCodeID
  JOIN dbo.vDrawerActivity DA 
       ON MMST.DrawerActivityID = DA.DrawerActivityID
 WHERE VTT.Description IN ('Adjustment', 'Charge', 'Refund', 'Sale') 
   AND DA.ValDrawerStatusID = 3 
   AND MMST.PostDateTime >= @PostDateStart 
   AND MMST.PostDateTime <= @PostDateEnd 	-- prior month
   AND CASE WHEN #RR.PostingMMSClubID = 9999 THEN TI.ClubID ELSE #RR.PostingMMSClubID END IN (SELECT StringField FROM #tmpList)

UPDATE #RevenueGLPosting			
   SET Adj_ValGroupID_Desc = CASE WHEN SortValGroupID = 2 AND TranTypeDescription = 'Automated Refund'
                                       THEN 'Membership Dues - Refund'
                                  WHEN SortValGroupID = 2 AND TranTypeDescription = 'Adjustment'
                                       THEN 'Current Month Dues - Adjustment'
                                  WHEN SortValGroupID = 2 AND TranTypeDescription IN ('Sale', 'Charge')
                                       THEN 'Current Month Dues'
                                  WHEN SortValGroupID IN (998, 999) AND TranTypeDescription = 'Automated Refund'
                                       THEN ProductDescription + ' - Refund'
                                  WHEN ProductID IN (3504,4280) AND TranTypeDescription = 'Adjustment'
                                       THEN ProductDescription + ' - Adjustment'
                                  WHEN SortValGroupID IN (998, 999) 
                                       THEN ProductDescription
                                  WHEN TranTypeDescription = 'Automated Refund'
                                       THEN GLGroupIDDescription + ' - Refund'
                                  ELSE GLGroupIDDescription END,
       Reconciliation_Adj_GLAccountNumber = CASE WHEN SortValGroupID = 2 AND TranTypeDescription = 'Adjustment'
                                                      THEN '4008'
                                                 WHEN SortValGroupID = 2 AND TranTypeDescription IN ('Sale', 'Charge')
                                                      THEN '4003'
                                                 WHEN ProductID IN (3504, 4280) AND TranTypeDescription = 'Adjustment'
                                                      THEN '4008'
                                                 ELSE GLAccountNumber END

UPDATE RevenueGLPosting
   SET RevenueGLPosting.Accum_AdjSalesTax = T.Adj_ItemSalesTax
  FROM #RevenueGLPosting RevenueGLPosting
  JOIN (SELECT Region_Club, Sum(ItemSalesTax) Adj_ItemSalesTax FROM #RevenueGLPosting GROUP BY Region_Club) T
    ON RevenueGLPosting.Region_Club = T.Region_Club

SELECT ItemAmount,
       ISNULL(ItemDiscountAmount,0) AS ItemDiscountAmount,                                      
       (ISNULL(ItemAmount,0) + ISNULL(ItemDiscountAmount,0)) as GLPostingAmount,    
       ProductDescription,
       PostDateTime,
       ItemSalesTax,
       ValGLGroupID,
       GLAccountNumber,
       GLSubAccountNumber,
       GLGroupIDDescription,
       GLTaxID,
       Posting_GLClubID,
       Posting_RegionDescription,
       Posting_ClubName,
       Posting_MMSClubID,
       Posting_ClubCode,       
       TransactionDescription,
       TranTypeDescription,
       Adj_ValGroupID_Desc as Reconciliation_Adj_ValGroupID_Desc,  
       Reconciliation_ReportMonthYear,
       Reconciliation_Posting_Sub_Account,
       Reconciliation_ReportHeader_TranType,
       Adj_ValGroupID_Desc + Reconciliation_Adj_GLAccountNumber + GLSubAccountNumber Reconciliation_ReportLineGrouping,
       Reconciliation_Adj_GLAccountNumber,
       'Positive = Credit Entry and Negative = Debit Entry' AS PostingInstruction,
---Embedded calcs
       Region_Club,
       Accum_AdjSalesTax,
       Cast(0 as Decimal(12,2)) AS Accum_GLPostingAmount,
       SortValGroupID
  INTO #Results       
  FROM #RevenueGLPosting

UNION ALL

SELECT ItemAmount,
       ISNULL(ItemDiscountAmount,0) AS ItemDiscountAmount,
       ISNULL(ItemDiscountAmount,0) as GLPostingAmount,
       ProductDescription,
       PostDateTime,
       0 as ItemSalesTax,
       ValGLGroupID,
       DiscountGLAccount as GLAccountNumber,
       GLSubAccountNumber,
       GLGroupIDDescription,
       GLTaxID,
       Posting_GLClubID,
       Posting_RegionDescription,
       Posting_ClubName,
       Posting_MMSClubID,
       Posting_ClubCode,      
       TransactionDescription,
       TranTypeDescription,
       Case
         WHEN Adj_ValGroupID_Desc LIKE '%- Refund%'
              THEN REPLACE(Adj_ValGroupID_Desc, '- Refund', '- Discount Refund')
         ELSE Adj_ValGroupID_Desc + ' - Discount'
         END Reconciliation_Adj_ValGroupID_Desc,
       Reconciliation_ReportMonthYear,
       Reconciliation_Posting_Sub_Account,
       Reconciliation_ReportHeader_TranType,
       CASE 
         WHEN Adj_ValGroupID_Desc LIKE '%- Refund%'
              THEN REPLACE(Adj_ValGroupID_Desc, '- Refund', '- Discount Refund') + COALESCE(DiscountGLAccount, 'NULL') + GLSubAccountNumber  
         ELSE Adj_ValGroupID_Desc + '- Discount' + COALESCE(DiscountGLAccount, 'NULL') + GLSubAccountNumber

       End Reconciliation_ReportLineGrouping,
       DiscountGLAccount as Reconciliation_Adj_GLAccountNumber,
       'Positive = Debit Entry and Negative = Credit Entry' AS PostingInstruction,
---Embedded calcs
       Region_Club,
       Accum_AdjSalesTax,
       Cast(0 as Decimal(12,2)) AS Accum_GLPostingAmount,
       SortValGroupID
  FROM #RevenueGLPosting
  Where ItemDiscountAmount <> 0
    AND ItemDiscountAmount Is Not Null

UPDATE Results
   SET Results.Accum_GLPostingAmount = T.GLPostingAmount
  FROM #Results Results
  JOIN (SELECT Reconciliation_ReportLineGrouping, Posting_MMSClubID, Sum(GLPostingAmount) GLPostingAmount FROM #Results GROUP BY Reconciliation_ReportLineGrouping, Posting_MMSClubID) T
    ON Results.Reconciliation_ReportLineGrouping = T.Reconciliation_ReportLineGrouping
  WHERE Results.Posting_MMSClubID = T.Posting_MMSClubID 


SELECT Posting_RegionDescription AS MMSRegionName,
       Posting_ClubName AS ClubName,
       Posting_ClubCode AS ClubCode,      
       Reconciliation_Adj_ValGroupID_Desc AS PostingDescription,
       Reconciliation_Adj_GLAccountNumber AS GLAccountNumber,
       Reconciliation_Posting_Sub_Account AS PostingSubAccount, 
       @ReportRunDateTime ReportRunDateTime,
       VCC1.CurrencyCode,
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
       Reconciliation_ReportMonthYear AS ReportMonthYear,
       SortValGroupID AS PostingSortGroup
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

SELECT Posting_RegionDescription AS MMSRegionName,
       Posting_ClubName AS ClubName,
       Posting_ClubCode AS ClubCode,      
       'Sales Tax' as PostingDescription,
       2130 AS GLAccountNumber,
       Cast(#Results.GLTaxID as Varchar) + '-000-000' as PostingSubAccount, 
       @ReportRunDateTime ReportRunDateTime,
       VCC1.CurrencyCode,
       USDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate,
       CASE WHEN Accum_AdjSalesTax >= 0 THEN Accum_AdjSalesTax ELSE 0 END AS LocalCurrencyCredit_Entry, 
       CASE WHEN Accum_AdjSalesTax < 0 THEN ABS(Accum_AdjSalesTax) ELSE 0 END AS LocalCurrencyDebit_Entry,
       CASE WHEN Accum_AdjSalesTax >= 0 THEN Accum_AdjSalesTax * USDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate ELSE 0 END AS USDCredit_Entry, 
       CASE WHEN Accum_AdjSalesTax < 0 THEN ABS(Accum_AdjSalesTax) * USDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate ELSE 0 END AS USDDebit_Entry,
       Reconciliation_ReportMonthYear AS ReportMonthYear,
       1000 as PostingSortGroup
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
 GROUP BY Posting_RegionDescription,
          Posting_ClubName,
          Posting_ClubCode,
          Cast(#Results.GLTaxID as Varchar) + '-000-000',
          Reconciliation_ReportMonthYear,
          CASE WHEN Accum_AdjSalesTax >= 0 THEN Accum_AdjSalesTax ELSE 0 END,
          CASE WHEN Accum_AdjSalesTax < 0 THEN ABS(Accum_AdjSalesTax) ELSE 0 END,
          CASE WHEN Accum_AdjSalesTax >= 0 THEN Accum_AdjSalesTax * USDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate ELSE 0 END,
          CASE WHEN Accum_AdjSalesTax < 0 THEN ABS(Accum_AdjSalesTax) * USDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate ELSE 0 END,
          VCC1.CurrencyCode,
          USDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate
 Order by MMSRegionName, ClubName,PostingSortGroup

-- remove temp tables

DROP TABLE #RefundTranIDs 
DROP TABLE #ReportRefunds 
DROP TABLE #RevenueGLPosting
DROP TABLE #Results
DROP TABLE #tmpList



END



