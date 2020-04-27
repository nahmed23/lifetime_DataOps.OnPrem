
CREATE PROC [dbo].[procAlteryx_DelinquentAgingBalanceSummaryByProductGroupMonthly] 


AS
BEGIN 
SET XACT_ABORT ON
SET NOCOUNT ON

IF 1=0 BEGIN
       SET FMTONLY OFF
     END

DECLARE @InsertedDateTime DATETIME
DECLARE @InsertedDateMonthEndingDimDateKey INT
DECLARE @LastDayInMonthFlag Varchar(1)
SET @InsertedDateTime = GetDate()
SET @InsertedDateMonthEndingDimDateKey = (SELECT MonthEndingDimDateKey FROM vReportDimDate WHERE CalendarDate = Cast(@InsertedDateTime as Date))
SET @LastDayInMonthFlag = (SELECT LastDayInMonthIndicator FROM vReportDimDate WHERE CalendarDate = Cast(@InsertedDateTime as Date))


IF @LastDayInMonthFlag = 'Y'
BEGIN  

SELECT  @InsertedDateMonthEndingDimDateKey AS MonthEndingDimDateKey,
        MS.ClubID AS MMSClubID,
        CASE WHEN MS.ValMembershipStatusID = 1 
		     THEN 'Terminated'
		     ELSE 'Non-Terminated'
			 END MembershipStatus,
		TranBalance.TranProductCategory,
		CASE WHEN IsNull(TranBalance.TranItemID,0) = 0  ------ TranBalance Table only looks back 120 days for Transactions, so older transactions are not persued for tracking
		     THEN 'Untracked'
			 ELSE Hier.DivisionName
			 END ProductRevenueReportingDivision,
        CASE WHEN IsNull(TranBalance.TranItemID,0) = 0
		     THEN 2
			 ELSE Hier.DimReportingHierarchyKey
			 END ProductDimReportingHierarchyKey,
		SUM(TranBalanceAmount) AS DelinquentBalance,       
        DimDate.CalendarMonthEndingDate AS OriginalTransactionMonth,   ------ TranBalance Table only looks back 120 days for Transactions, so oldest reported month may be only a partial month
		@InsertedDateTime AS InsertedDateTime
		
FROM  vTranBalance TranBalance
 JOIN vMembership MS
   ON TranBalance.MembershipID = MS.MembershipID
 LEFT JOIN vTranItem  TI
   ON IsNull(TranBalance.TranItemID,0) = TI.TranItemID
 LEFT JOIN vReportDimProduct Product
   ON TI.ProductID = Product.MMSProductID
 LEFT JOIN vReportDimReportingHierarchy Hier
   ON Product.DimReportingHierarchyKey = Hier.DimReportingHierarchyKey
 LEFT JOIN vReportDimDate DimDate
   ON Cast(TI.InsertedDateTime AS Date) = DimDate.CalendarDate
GROUP BY CASE WHEN MS.ValMembershipStatusID = 1 
		     THEN 'Terminated'
		     ELSE 'Non-Terminated'
			 END,
		CASE WHEN IsNull(TranBalance.TranItemID,0) = 0
		     THEN 'Untracked'
			 ELSE Hier.DivisionName
			 END,
        CASE WHEN IsNull(TranBalance.TranItemID,0) = 0
		     THEN 2
			 ELSE Hier.DimReportingHierarchyKey
			 END,
			 DimDate.CalendarMonthEndingDate,
			 TranBalance.TranProductCategory,
			 MS.ClubID
 ORDER BY MS.ClubID,
          CASE WHEN MS.ValMembershipStatusID = 1 
		     THEN 'Terminated'
		     ELSE 'Non-Terminated'
			 END,
			 TranBalance.TranProductCategory,
			 CASE WHEN IsNull(TranBalance.TranItemID,0) = 0
		     THEN 'Untracked'
			 ELSE Hier.DivisionName
			 END,
			 DimDate.CalendarMonthEndingDate


	END

END
