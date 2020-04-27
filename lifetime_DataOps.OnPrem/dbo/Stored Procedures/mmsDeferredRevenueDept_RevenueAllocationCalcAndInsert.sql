

CREATE Procedure [dbo].[mmsDeferredRevenueDept_RevenueAllocationCalcAndInsert]

AS
BEGIN
SET XACT_ABORT  ON
SET NOCOUNT  ON

------=================================================================================================
------Object:				dbo.mmsDeferredRevenueDept_RevenueAllocationCalcAndInsert
------Author:				Susan Myrick
------Create Date:			9/2/08
------Description:			Calculates Revenue allocation for transactions Month to Date through yesterday.  
------						This stored procedure us executed by a scheduled job.
------Parameters:			MMS POS Transactions, Month to Date through yesterday and the 3 current 
------						departments which have deferred revenue: Member Activities, Tennis and Pro Shop.
------						( Pro Shop because it is reported together with Tennis )
------
------                      4/8/10 ML Added columns Quantity and MMSTranItemID to result set
------                      4/13/2010 ML Split queries into two seperate queries depending if 
------                      MMSR.ItemAmount is positive or negative.
------                      04/27/2010 MLL Removed special logic for Refunds in calculating GLRevenueMonth
------                      06/24/2010 MLL Add Department IDs 32 and 33 to queries
------                      07/01/2010 MLL Add Discount logic
------                      05/31/2011 BSD Added DepartmentID 33
------==================================================================================================

DECLARE @StartDatePriorMonth  AS VARCHAR(6)
DECLARE @StartMonth AS VARCHAR(6)
DECLARE @EndDate AS DATETIME
DECLARE @YearFromStartDatePriorMonth AS VARCHAR(6)
DECLARE @StartDate AS DATETIME

SET @StartDate = CONVERT(DATETIME,LEFT(CONVERT(VARCHAR,GetDate()-1,110),2)+ '/01/'+ LEFT(CONVERT(VARCHAR,GetDate()-1,112),4))
SET @StartDatePriorMonth = LEFT(CONVERT(VARCHAR,DATEADD(m,-1,@StartDate),112),6)
SET @StartMonth = LEFT(CONVERT(VARCHAR,@StartDate,112),6)
SET @EndDate = DATEADD(m,1,@StartDate)
SET @YearFromStartDatePriorMonth = LEFT(CONVERT(VARCHAR,DATEADD(m,-1,@StartDate),112),6)+100


DELETE FROM vDeferredRevenueAllocationSummary WHERE MMSPostMonth = @StartMonth



------ Create a temp table 1 to hold Club specific deferred revenue allocations 
CREATE TABLE #TMPDefAllocation1(MMSPostingClubID INT, AllocationProductGroupDescription VARCHAR(50),MMSProductID INT,
                               MMSPostMonth VARCHAR(6),GLRevenueAccount VARCHAR(5),GLRevenueSubAccount VARCHAR(11),
                               GLRevenueMonth VARCHAR(6), RevenueMonthAllocation MONEY, TransactionType VARCHAR(50),
                               ProductDepartmentID VARCHAR(2), 
                               Quantity INT, RevenueMonthQuantityAllocation DECIMAL(12,4), 
                               RevenueMonthDiscountAllocation DECIMAL(10,2), RefundGLAccountNumber VARCHAR(5), DiscountGLAccount VARCHAR(5))
INSERT INTO #TMPDefAllocation1 (MMSPostingClubID,AllocationProductGroupDescription,MMSProductID,
                               MMSPostMonth,GLRevenueAccount,GLRevenueSubAccount, GLRevenueMonth, 
                               RevenueMonthAllocation, TransactionType,ProductDepartmentID, 
                               Quantity, RevenueMonthQuantityAllocation,
                               RevenueMonthDiscountAllocation,RefundGLAccountNumber,DiscountGLAccount)


Select MMSR.PostingClubID,VRAPG.Description,MMSR.ProductID,
       @StartMonth AS MMSPostMonth,PGbyC.GLRevenueAccount,PGbyC.GLRevenueSubAccount,
       CASE WHEN  RA2.PostingMonth = 0
             THEN @StartMonth
            WHEN RA2.PostingMonth <@StartMonth
             THEN @StartMonth
            ELSE RA2.PostingMonth
        END GLRevenueMonth,
       CASE -----WHEN MMSR.TranTypeDescription = 'Refund'
             -----THEN Sum(MMSR.ItemAmount)
            WHEN RA2.PostingMonth = 0 
             THEN Sum(MMSR.ItemAmount)
            WHEN RA2.PostingMonth = @StartDatePriorMonth
             THEN Sum(MMSR.ItemAmount) * RA2.AccumulatedRatio
            ELSE Sum(MMSR.ItemAmount) * RA2.Ratio
        END RevenueMonthAllocation,
       MMSR.TranTypeDescription, MMSR.DepartmentID, SUM(MMSR.Quantity) AS Quantity, 
       CASE -----WHEN MMSR.TranTypeDescription = 'Refund'
             -----THEN Sum(MMSR.Quantity)
            WHEN RA2.PostingMonth = 0 
             THEN Sum(MMSR.Quantity)
            WHEN RA2.PostingMonth = @StartDatePriorMonth
             THEN Sum(MMSR.Quantity) * RA2.AccumulatedRatio
            ELSE Sum(MMSR.Quantity) * RA2.Ratio
        END RevenueMonthQuantityAllocation,
		CASE When RA2.PostingMonth = 0
                                   Then Sum(MMSR.ItemDiscountAmount)
                                   When RA2.PostingMonth = @StartDatePriorMonth
                                   Then Sum(MMSR.ItemDiscountAmount) * RA2.AccumulatedRatio
                                   Else Sum(MMSR.ItemDiscountAmount) * RA2.Ratio
                           END RevenueMonthDiscountAllocation,
        GA.RefundGLAccountNumber,
        GA.DiscountGLAccount
      
From vMMSRevenueReportSummary MMSR
JOIN vProductGroupByClub PGbyC
    ON PGbyC.MMSClubID = MMSR.PostingClubID
    AND PGbyC.ProductID = MMSR.ProductID
JOIN vRevenueAllocationRates RA2
    ON RA2.ValRevenueAllocationProductGroupID = PGbyC.ValRevenueAllocationProductGroupID
JOIN vValRevenueAllocationProductGroup VRAPG
    ON PGbyC.ValRevenueAllocationProductGroupID = VRAPG.ValRevenueAllocationProductGroupID
Join vGLAccount GA on GA.RevenueGLAccountNumber = PGbyC.GLRevenueAccount
Where MMSR.PostDateTime >= @StartDate
  AND MMSR.PostDateTime < @EndDate
  AND MMSR.DepartmentID IN (24,25,26,27,28,29,31,18,15,17,21,32,34,33,30,35,36) 
AND (RA2.PostingMonth >= @StartDatePriorMonth or RA2.PostingMonth = 0)
  AND (RA2.ActivityFinalPostingMonth < @YearFromStartDatePriorMonth OR RA2.ActivityFinalPostingMonth IS Null )
AND MMSR.ItemAmount >= 0 --MLL Added 4/13/2010
Group BY MMSR.PostingClubID,MMSR.ProductID,RA2.PostingMonth,RA2.AccumulatedRatio,RA2.Ratio,
         VRAPG.Description,PGbyC.GLRevenueAccount,PGbyC.GLRevenueSubAccount,MMSR.TranTypeDescription,
         MMSR.DepartmentID,
        GA.RefundGLAccountNumber,
        GA.DiscountGLAccount
--Order by MMSR.ProductID

UNION ALL

Select MMSR.PostingClubID,VRAPG.Description,MMSR.ProductID,
       @StartMonth AS MMSPostMonth,PGbyC.GLRevenueAccount,PGbyC.GLRevenueSubAccount,
       CASE WHEN  RA2.PostingMonth = 0
             THEN @StartMonth
            WHEN RA2.PostingMonth <@StartMonth
             THEN @StartMonth
            ELSE RA2.PostingMonth
        END GLRevenueMonth,
       CASE -----WHEN MMSR.TranTypeDescription = 'Refund'
             -----THEN Sum(MMSR.ItemAmount)
            WHEN RA2.PostingMonth = 0 
             THEN Sum(MMSR.ItemAmount)
            WHEN RA2.PostingMonth = @StartDatePriorMonth
             THEN Sum(MMSR.ItemAmount) * RA2.AccumulatedRatio
            ELSE Sum(MMSR.ItemAmount) * RA2.Ratio
        END RevenueMonthAllocation,
       MMSR.TranTypeDescription, MMSR.DepartmentID, SUM(MMSR.Quantity * -1) AS Quantity, 
       CASE -----WHEN MMSR.TranTypeDescription = 'Refund'
             -----THEN Sum(MMSR.Quantity)
            WHEN RA2.PostingMonth = 0 
             THEN Sum(MMSR.Quantity * -1)
            WHEN RA2.PostingMonth = @StartDatePriorMonth
             THEN Sum(MMSR.Quantity * -1) * RA2.AccumulatedRatio
            ELSE Sum(MMSR.Quantity * -1) * RA2.Ratio
        END RevenueMonthQuantityAllocation,
		CASE When RA2.PostingMonth = 0
                                   Then Sum(MMSR.ItemDiscountAmount)
                                   When RA2.PostingMonth = @StartDatePriorMonth
                                   Then Sum(MMSR.ItemDiscountAmount) * RA2.AccumulatedRatio
                                   Else Sum(MMSR.ItemDiscountAmount) * RA2.Ratio
                           END RevenueMonthDiscountAllocation,
        GA.RefundGLAccountNumber,
        GA.DiscountGLAccount
      
From vMMSRevenueReportSummary MMSR
JOIN vProductGroupByClub PGbyC
    ON PGbyC.MMSClubID = MMSR.PostingClubID
    AND PGbyC.ProductID = MMSR.ProductID
JOIN vRevenueAllocationRates RA2
    ON RA2.ValRevenueAllocationProductGroupID = PGbyC.ValRevenueAllocationProductGroupID
JOIN vValRevenueAllocationProductGroup VRAPG
    ON PGbyC.ValRevenueAllocationProductGroupID = VRAPG.ValRevenueAllocationProductGroupID
Join vGLAccount GA on GA.RevenueGLAccountNumber = PGbyC.GLRevenueAccount
Where MMSR.PostDateTime >= @StartDate
  AND MMSR.PostDateTime < @EndDate
  AND MMSR.DepartmentID IN (24,25,26,27,28,29,31,18,15,17,21,32,34,33,30,35,36) 
AND (RA2.PostingMonth >= @StartDatePriorMonth or RA2.PostingMonth = 0)
  AND (RA2.ActivityFinalPostingMonth < @YearFromStartDatePriorMonth OR RA2.ActivityFinalPostingMonth IS Null )
AND MMSR.ItemAmount < 0 --MLL Added 4/13/2010
Group BY MMSR.PostingClubID,MMSR.ProductID,RA2.PostingMonth,RA2.AccumulatedRatio,RA2.Ratio,
         VRAPG.Description,PGbyC.GLRevenueAccount,PGbyC.GLRevenueSubAccount,MMSR.TranTypeDescription,
         MMSR.DepartmentID ,
        GA.RefundGLAccountNumber,
        GA.DiscountGLAccount
Order by MMSR.ProductID


------ Create a temp table 2 to hold Non-Club specific deferred revenue allocations 
CREATE TABLE #TMPDefAllocation2(MMSPostingClubID INT,AllocationProductGroupDescription VARCHAR(50),MMSProductID INT,
                               MMSPostMonth VARCHAR(6),GLRevenueAccount VARCHAR(5),GLRevenueSubAccount VARCHAR(11),
                               GLRevenueMonth VARCHAR(6), RevenueMonthAllocation MONEY, TransactionType VARCHAR(50),
                               ProductDepartmentID VARCHAR(2), 
                               Quantity INT, RevenueMonthQuantityAllocation DECIMAL(12,4),
                               RevenueMonthDiscountAllocation DECIMAL(10,2), RefundGLAccountNumber VARCHAR(5), DiscountGLAccount VARCHAR(5))
INSERT INTO #TMPDefAllocation2(MMSPostingClubID,AllocationProductGroupDescription,MMSProductID,
                               MMSPostMonth, GLRevenueAccount,GLRevenueSubAccount,GLRevenueMonth, 
                               RevenueMonthAllocation,TransactionType,ProductDepartmentID, 
                               Quantity, RevenueMonthQuantityAllocation,
                               RevenueMonthDiscountAllocation,RefundGLAccountNumber,DiscountGLAccount)

Select MMSR.PostingClubID,VRAPG.Description,MMSR.ProductID,
       @StartMonth AS MMSPostMonth,PG.GLRevenueAccount,PG.GLRevenueSubAccount,
       CASE WHEN  RA.PostingMonth = 0 OR RA.PostingMonth IS Null
             THEN @StartMonth
            WHEN RA.PostingMonth <@StartMonth
             THEN @StartMonth
            ELSE RA.PostingMonth
        END GLRevenueMonth,
       CASE ------WHEN MMSR.TranTypeDescription = 'Refund'
             ------THEN Sum(MMSR.ItemAmount)
            WHEN RA.PostingMonth = 0 OR RA.PostingMonth IS Null
             THEN Sum(MMSR.ItemAmount)
            WHEN RA.PostingMonth = @StartDatePriorMonth
             THEN Sum(MMSR.ItemAmount) * RA.AccumulatedRatio
            ELSE Sum(MMSR.ItemAmount) * RA.Ratio
        END RevenueMonthAllocation,
        MMSR.TranTypeDescription, MMSR.DepartmentID, SUM(MMSR.Quantity) AS Quantity, 
       CASE ------WHEN MMSR.TranTypeDescription = 'Refund'
             ------THEN Sum(MMSR.Quantity)
            WHEN RA.PostingMonth = 0 OR RA.PostingMonth IS Null
             THEN Sum(MMSR.Quantity)
            WHEN RA.PostingMonth = @StartDatePriorMonth
             THEN Sum(MMSR.Quantity) * RA.AccumulatedRatio
            ELSE Sum(MMSR.Quantity) * RA.Ratio
        END RevenueMonthQuantityAllocation,
		CASE When RA.PostingMonth = 0
                                   Then Sum(MMSR.ItemDiscountAmount)
                                   When RA.PostingMonth = @StartDatePriorMonth
                                   Then Sum(MMSR.ItemDiscountAmount) * RA.AccumulatedRatio
                                   Else Sum(MMSR.ItemDiscountAmount) * RA.Ratio
                           END RevenueMonthDiscountAllocation,
        GA.RefundGLAccountNumber,
        GA.DiscountGLAccount
      
From vMMSRevenueReportSummary MMSR
LEFT JOIN vProductGroupByClub PGbyC
    ON PGbyC.MMSClubID = MMSR.PostingClubID
    AND PGbyC.ProductID = MMSR.ProductID
LEFT JOIN vProductGroup PG
    ON PG.ProductID = MMSR.ProductID
LEFT JOIN vRevenueAllocationRates RA
    ON RA.ValRevenueAllocationProductGroupID = PG.ValRevenueAllocationProductGroupID
LEFT JOIN vValRevenueAllocationProductGroup VRAPG
    ON PG.ValRevenueAllocationProductGroupID = VRAPG.ValRevenueAllocationProductGroupID
Join vGLAccount GA on GA.RevenueGLAccountNumber = PG.GLRevenueAccount
Where PGbyC.ProductGroupByClubID Is Null
  AND MMSR.PostDateTime >= @StartDate
  AND MMSR.PostDateTime < @EndDate
  AND MMSR.DepartmentID IN (24,25,26,27,28,29,31,18,15,17,21,32,34,33,30,35,36)
  AND (RA.PostingMonth >= @StartDatePriorMonth or RA.PostingMonth = 0 OR RA.PostingMonth IS Null)
  AND (RA.ActivityFinalPostingMonth < @YearFromStartDatePriorMonth OR RA.ActivityFinalPostingMonth IS Null )
  AND (PG.ValProductGroupID <> 25 OR PG.ValProductGroupID Is Null)
AND MMSR.ItemAmount >= 0 --MLL Added 4/13/2010
Group BY MMSR.PostingClubID,MMSR.ProductID,RA.PostingMonth,RA.AccumulatedRatio,RA.Ratio,
         VRAPG.Description,PG.GLRevenueAccount,PG.GLRevenueSubAccount,MMSR.TranTypeDescription, 
         MMSR.DepartmentID,
        GA.RefundGLAccountNumber,
        GA.DiscountGLAccount
--Order by MMSR.ProductID

UNION ALL

Select MMSR.PostingClubID,VRAPG.Description,MMSR.ProductID,
       @StartMonth AS MMSPostMonth,PG.GLRevenueAccount,PG.GLRevenueSubAccount,
       CASE WHEN  RA.PostingMonth = 0 OR RA.PostingMonth IS Null
             THEN @StartMonth
            WHEN RA.PostingMonth <@StartMonth
             THEN @StartMonth
            ELSE RA.PostingMonth
        END GLRevenueMonth,
       CASE ------WHEN MMSR.TranTypeDescription = 'Refund'
             ------THEN Sum(MMSR.ItemAmount)
            WHEN RA.PostingMonth = 0 OR RA.PostingMonth IS Null
             THEN Sum(MMSR.ItemAmount)
            WHEN RA.PostingMonth = @StartDatePriorMonth
             THEN Sum(MMSR.ItemAmount) * RA.AccumulatedRatio
            ELSE Sum(MMSR.ItemAmount) * RA.Ratio
        END RevenueMonthAllocation,
        MMSR.TranTypeDescription, MMSR.DepartmentID, SUM(MMSR.Quantity * -1) AS Quantity, 
       CASE ------WHEN MMSR.TranTypeDescription = 'Refund'
             ------THEN Sum(MMSR.Quantity)
            WHEN RA.PostingMonth = 0 OR RA.PostingMonth IS Null
             THEN Sum(MMSR.Quantity * -1)
            WHEN RA.PostingMonth = @StartDatePriorMonth
             THEN Sum(MMSR.Quantity * -1) * RA.AccumulatedRatio
            ELSE Sum(MMSR.Quantity * -1) * RA.Ratio
        END RevenueMonthQuantityAllocation,
		CASE When RA.PostingMonth = 0
                                   Then Sum(MMSR.ItemDiscountAmount)
                                   When RA.PostingMonth = @StartDatePriorMonth
                                   Then Sum(MMSR.ItemDiscountAmount) * RA.AccumulatedRatio
                                   Else Sum(MMSR.ItemDiscountAmount) * RA.Ratio
                           END RevenueMonthDiscountAllocation,
        GA.RefundGLAccountNumber,
        GA.DiscountGLAccount
      
From vMMSRevenueReportSummary MMSR
LEFT JOIN vProductGroupByClub PGbyC
    ON PGbyC.MMSClubID = MMSR.PostingClubID
    AND PGbyC.ProductID = MMSR.ProductID
LEFT JOIN vProductGroup PG
    ON PG.ProductID = MMSR.ProductID
LEFT JOIN vRevenueAllocationRates RA
    ON RA.ValRevenueAllocationProductGroupID = PG.ValRevenueAllocationProductGroupID
LEFT JOIN vValRevenueAllocationProductGroup VRAPG
    ON PG.ValRevenueAllocationProductGroupID = VRAPG.ValRevenueAllocationProductGroupID
Join vGLAccount GA on GA.RevenueGLAccountNumber = PG.GLRevenueAccount
Where PGbyC.ProductGroupByClubID Is Null
  AND MMSR.PostDateTime >= @StartDate
  AND MMSR.PostDateTime < @EndDate
  AND MMSR.DepartmentID IN (24,25,26,27,28,29,31,18,15,17,21,32,34,33,30,35,36)
  AND (RA.PostingMonth >= @StartDatePriorMonth or RA.PostingMonth = 0 OR RA.PostingMonth IS Null)
  AND (RA.ActivityFinalPostingMonth < @YearFromStartDatePriorMonth OR RA.ActivityFinalPostingMonth IS Null )
  AND (PG.ValProductGroupID <> 25 OR PG.ValProductGroupID Is Null)
AND MMSR.ItemAmount < 0 --MLL Added 4/13/2010
Group BY MMSR.PostingClubID,MMSR.ProductID,RA.PostingMonth,RA.AccumulatedRatio,RA.Ratio,
         VRAPG.Description,PG.GLRevenueAccount,PG.GLRevenueSubAccount,MMSR.TranTypeDescription, 
         MMSR.DepartmentID ,
        GA.RefundGLAccountNumber,
        GA.DiscountGLAccount
Order by MMSR.ProductID

---- Combine the results from both tables to create a single data set

INSERT INTO vDeferredRevenueAllocationSummary(MMSClubID,RevenueAllocationProductGroupDescription,
            ProductID,MMSPostMonth,GLRevenueAccount,GLRevenueSubAccount,GLRevenueMonth, 
            RevenueMonthAllocation,TransactionType,ProductDepartmentID, 
            Quantity, RevenueMonthQuantityAllocation,
            RevenueMonthDiscountAllocation,RefundGLAccountNumber,DiscountGLAccount)

    Select MMSPostingClubID,AllocationProductGroupDescription,MMSProductID,
       MMSPostMonth,GLRevenueAccount,GLRevenueSubAccount,GLRevenueMonth, RevenueMonthAllocation,
       TransactionType,ProductDepartmentID, Quantity, RevenueMonthQuantityAllocation,
            RevenueMonthDiscountAllocation,RefundGLAccountNumber,DiscountGLAccount
       from #TMPDefAllocation2

INSERT INTO vDeferredRevenueAllocationSummary(MMSClubID,RevenueAllocationProductGroupDescription,
            ProductID,MMSPostMonth,GLRevenueAccount,GLRevenueSubAccount,GLRevenueMonth, 
            RevenueMonthAllocation,TransactionType,ProductDepartmentID, 
            Quantity, RevenueMonthQuantityAllocation,
            RevenueMonthDiscountAllocation,RefundGLAccountNumber,DiscountGLAccount) 

    Select MMSPostingClubID,AllocationProductGroupDescription,MMSProductID,
       MMSPostMonth,GLRevenueAccount,GLRevenueSubAccount,GLRevenueMonth, RevenueMonthAllocation,
       TransactionType,ProductDepartmentID, Quantity, RevenueMonthQuantityAllocation,
       RevenueMonthDiscountAllocation,RefundGLAccountNumber,DiscountGLAccount
       from #TMPDefAllocation1


Select CONVERT(VARCHAR,@StartDate,101)AS ProcessingCompletedMonth

DROP TABLE #TMPDefAllocation1
DROP TABLE #TMPDefAllocation2


END

