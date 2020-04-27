

CREATE VIEW vDeferredRevenueAllocationSummary
AS
SELECT DeferredRevenueAllocationSummaryID,
	   MMSClubID,
	   RevenueAllocationProductGroupDescription,
	   ProductID,
	   MMSPostMonth,
	   GLRevenueAccount,
	   GLRevenueSubAccount,
	   GLRevenueMonth,
	   RevenueMonthAllocation,
	   TransactionType,
	   ProductDepartmentID,
       Quantity,
       RevenueMonthQuantityAllocation,
       RevenueMonthDiscountAllocation,
       RefundGLAccountNumber,
       DiscountGLAccount
FROM DeferredRevenueAllocationSummary WITH (NOLOCK)
