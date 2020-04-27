

CREATE   PROC mmsDeferredRevenueDept_GLPosting (
	@YearMonth VARCHAR(10)
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON
-- =======================================================================================================
-- Object:			dbo.mmsDeferredRevenueDept_GLPosting
-- Author:			Susan Myrick
-- Create date: 	9/3/08
-- Description:		A listing of deferred revenue amounts which can be recognized in the selected month. 
--                  The Accounting group uses this data as a source for their monthly G.L. entry.
-- 	
--                  06/07/2010 MLL Modified WHERE clause to allow Refunds
--                  07/06/2010 MLL Add Discounts
-- Exec mmsDeferredRevenueDept_GLPosting '200808'
-- =======================================================================================================

-- Report Logging
DECLARE @Identity int
INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
SET @Identity = @@IDENTITY

SELECT R.Description AS RegionDescription, 
       C.ClubName, 
       CASE 
            WHEN DRAS.Transactiontype  = 'Refund' 
                 THEN (DRAS.RevenueAllocationProductGroupDescription + ' – Refund') 
            ELSE DRAS.RevenueAllocationProductGroupDescription 
       END AS RevenueAllocationProductGroupDescription,
       CASE 
            WHEN DRAS.TransactionType = 'Refund' 
                 THEN P.Description + '- Refund' 
            ELSE P.Description 
       END AS ProductDescription,
       CASE 
            WHEN DRAS.TransactionType = 'Refund' 
                 THEN DRAS.RefundGLAccountNumber 
            ELSE DRAS.GLRevenueAccount 
       END AS GLRevenueAccount,
       C.GLClubID, 
       DRAS.GLRevenueSubAccount, 
       (ISNULL(DRAS.RevenueMonthAllocation,0) + ISNULL(DRAS.RevenueMonthDiscountAllocation,0)) AS RevenueMonthAllocation,
       DRAS.GLRevenueMonth,
       DRAS.ProductID,
       DRAS.TransactionType,
       'Positive = Credit Entry and Negative = Debit Entry' AS PostingInstruction
	
FROM vDeferredRevenueAllocationSummary DRAS
      JOIN vCLUB C
        ON C.ClubID=DRAS.MMSClubID
      JOIN vValRegion R
        ON R.ValRegionID=C.ValRegionID
      JOIN vProduct P
        ON DRAS.ProductID=P.ProductID
  
WHERE DRAS.GLRevenueMonth=@YearMonth 
  AND P.GLAccountNumber = '2310' 
  AND (ISNULL(DRAS.RevenueMonthAllocation,0) + ISNULL(DRAS.RevenueMonthDiscountAllocation,0))<> 0

UNION ALL

SELECT R.Description AS RegionDescription, 
       C.ClubName, 
       CASE 
            WHEN DRAS.Transactiontype  = 'Refund' 
                 THEN (DRAS.RevenueAllocationProductGroupDescription + ' – Discount Refund') 
            ELSE (DRAS.RevenueAllocationProductGroupDescription + ' - Discount')
       END AS RevenueAllocationProductGroupDescription,
       CASE 
            WHEN DRAS.TransactionType = 'Refund' 
                 THEN P.Description + '- Discount Refund' 
            ELSE (P.Description + '- Discount' )
       END AS ProductDescription,
       DRAS.DiscountGLAccount,
       C.GLClubID, 
       DRAS.GLRevenueSubAccount, 
       ISNULL(DRAS.RevenueMonthDiscountAllocation,0) AS RevenueMonthAllocation,
       DRAS.GLRevenueMonth,
       DRAS.ProductID,
       DRAS.TransactionType,
       'Positive = Debit Entry and Negative = Credit Entry'  AS PostingInstruction
	
FROM vDeferredRevenueAllocationSummary DRAS
      JOIN vCLUB C
        ON C.ClubID=DRAS.MMSClubID
      JOIN vValRegion R
        ON R.ValRegionID=C.ValRegionID
      JOIN vProduct P
        ON DRAS.ProductID=P.ProductID
  
WHERE DRAS.GLRevenueMonth=@YearMonth 
  AND P.GLAccountNumber = '2310' 
  AND DRAS.RevenueMonthDiscountAllocation IS NOT NULL
  AND DRAS.RevenueMonthDiscountAllocation <> 0


 -- Report Logging
UPDATE HyperionReportLog
SET EndDateTime = getdate()
WHERE ReportLogID = @Identity

END
