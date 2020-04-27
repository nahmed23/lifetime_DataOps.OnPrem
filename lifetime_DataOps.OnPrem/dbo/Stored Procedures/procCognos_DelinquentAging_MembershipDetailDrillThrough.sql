
CREATE PROC [dbo].[procCognos_DelinquentAging_MembershipDetailDrillThrough] (
    @ReportDate DATETIME,
    @PrimaryMemberID INT,
    @TransactionType VARCHAR(50)
)

AS
BEGIN 
SET XACT_ABORT ON
SET NOCOUNT ON

------ Sample Execution
--- Exec procCognos_DelinquentAgingMembershipDetailDrillThrough '1/26/2017',102816710,'Adjustment'
------

DECLARE @SecondOfReportMonth DateTime
DECLARE @ReportDatePlus1 DateTime
DECLARE @ReportRunDateTime Varchar(21)

SET @SecondOfReportMonth = (SELECT DateAdd(day,1,CalendarMonthStartingDate) FROM vReportDimDate WHERE CalendarDate = @ReportDate)
SET @ReportDatePlus1 = DateAdd(day,1,@ReportDate) 
SET @ReportRunDateTime = Replace(Substring(convert(varchar,GetDate(),100),1,6)+', '+Substring(convert(varchar,GetDate(),100),8,10)+' '+Substring(convert(varchar,GetDate(),100),18,2),'  ',' ')


SELECT MMSTran.MembershipID, 
       @PrimaryMemberID AS PrimaryMemberID,
       TranMember.MemberID AS TransactionMemberID,
	   TranMember.FirstName AS TransactionMemberFirstName,
	   TranMember.LastName AS TransactionMemberLastName,
	   MMSTran.PostDateTime,
	   Employee.EmployeeID AS TransactionEmployeeID,
	   Employee.FirstName AS TransactionEmployeeFirstName,
	   Employee.LastName AS TransactionEmployeeLastName,
	   ReasonCode.Description AS TransactionReason,
	   MMSTran.ReceiptComment AS TransactionComment,
	   MMSTran.TranAmount,
	   TranItem.ItemAmount,
	   TranItem.ItemSalesTax,
	   Product.ProductID,
	   Product.Description AS Product,
	   @SecondOfReportMonth as HeaderTransactionStartDate,
	   @ReportDate As HeaderTransactionEndDate,
	   @TransactionType AS HeaderTransactionType,
	   @ReportRunDateTime AS ReportRunDateTime
from vMMSTran MMSTran
 JOIN vMember TranMember
   ON TranMember.MemberID = MMSTran.MemberID
 JOIN vReasonCode ReasonCode
   ON MMSTran.ReasonCodeID = ReasonCode.ReasonCodeID
 JOIN vMember PrimaryMember
   ON MMSTran.MembershipID = PrimaryMember.MembershipID
 JOIN vEmployee Employee
   ON MMSTran.EmployeeID = Employee.EmployeeID
 JOIN vValTranType TranType
   ON MMSTran.ValTranTypeID = TranType.ValTranTypeID
 LEFT JOIN vTranItem TranItem
   ON MMSTran.MMSTranID = TranItem.MMSTranID
 LEFT JOIN vProduct Product
   ON TranItem.ProductID = Product.ProductID
WHERE PrimaryMember.MemberID = @PrimaryMemberID
AND MMSTran.PostDateTime >= @SecondOfReportMonth
AND MMSTran.PostDateTime < @ReportDatePlus1
AND TranType.Description = @TransactionType
AND PrimaryMember.ValMemberTypeID = 1


END
