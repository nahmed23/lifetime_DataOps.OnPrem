




/*

exec procCognos_ApprovedEFTProductGroupDetail 'All'
exec procCognos_ApprovedEFTProductGroupDetail '151|10'

*/

CREATE PROCEDURE [dbo].[procCognos_ApprovedEFTProductGroupDetail] (
 @ClubIDList VARCHAR(2000)
)

AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

DECLARE @DraftDate AS DateTime 
SET @DraftDate = CONVERT(DATE,GETDATE(),100)

-- report sub headers
DECLARE @ReportRunDateTime VARCHAR(21) 
SET @ReportRunDateTime = Replace(Substring(convert(varchar,getdate(),100),1,6)+', '+Substring(convert(varchar,GETDATE(),100),8,10)+' '+Substring(convert(varchar,getdate(),100),18,2),'  ',' ')


  CREATE TABLE #tmpList (StringField VARCHAR(50))
  CREATE TABLE #Clubs (ClubID VARCHAR(50))
IF @ClubIDList <> 'All'
BEGIN
   EXEC procParseStringList @ClubIDList
   INSERT INTO #Clubs (ClubID) SELECT StringField FROM #tmpList
   TRUNCATE TABLE #tmpList
END
ELSE
BEGIN
   INSERT INTO #Clubs (ClubID) SELECT ClubID FROM vClub WHERE DisplayUIFlag = 1
END  


/********  Foreign Currency Stuff ********/
CREATE TABLE #PlanRate (PlanRate DECIMAL(14,4), FromCurrencyCode VARCHAR(15), PlanYear INT)
INSERT INTO #PlanRate
SELECT PlanExchangeRate, FromCurrencyCode, PlanYear
FROM PlanExchangeRate
WHERE PlanYear >= Year(@DraftDate)
  AND PlanYear <= Year(@DraftDate)
  AND ToCurrencyCode = 'USD'


---- Today's EFT payments on account
Select MMSTran.MembershipID, MemberID, PostDateTime,TranDate, POSAmount, TranAmount,EmployeeID,
R.ReasonCodeID, R.Description as TranReason, MS.ClubID,
CASE WHEN R.ReasonCodeID = 38
     THEN 'Dues'
	 Else 'Products'
	 End TranProductCategory
INTO #TodaysPayments
from vMMSTran  MMSTran
Join vReasonCode R
     On MMSTran.ReasonCodeID = R.ReasonCodeID
Join vMembership MS
     On MS.membershipID = MMSTran.MembershipID
Where ValTranTypeID = 2
AND PostDateTime > @DraftDate  --- update to today’s EFT Draft date
AND R.ReasonCodeID in(38,253)  ----"Monthly EFT Dues Payment Successful" and "Monthly EFT Recur Prod Payment Successful"
Order by MembershipID, POSAmount, TranAmount, PostDateTime, TranDate


	create table #TodaysCharges (
	            id int, 
				MembershipID int, 
				PostDateTime datetime, 
				Amount decimal(10,2),
				ProductAmount decimal(10,2), 
				ItemSalesTax decimal(10,2),
				ReasonCodeID int, 
				TranReason varchar(50), 
				MMSProductID int,
				ProductDescription varchar(50),
				RevenueDepartment varchar(50),
				RevenueProductGroup varchar(50),
				WorkdayCostCenter varchar(6), 
				WorkdayRegion varchar(4), 
				ClubID int, 
				ValCurrencyCodeID tinyint,	
				FourDigitYearDashTwoDigitMonth varchar(7),
				TranProductCategory varchar(50))


if DAY(@DraftDate) <> 1 -- this data is available in TranBalance on the first
begin
	--- Today's charges
	insert INTO #TodaysCharges
	Select 1 as id, MembershipID, PostDateTime, TranAmount as Amount,TI.ItemAmount as ProductAmount, TI.ItemSalesTax,R.ReasonCodeID, R.Description as TranReason, 
	DP.MMSProductID,DP.ProductDescription,DP.RevenueReportingDepartmentName as RevenueDepartment, DP.RevenueProductGroupName AS RevenueProductGroup, 
	DP.WorkdayCostCenter, C.WorkdayRegion, C.ClubID, C.ValCurrencyCodeID,
	Case When Len((Convert(Varchar,DatePart(Year,MMSTran.PostDateTime))+'-'+Convert(Varchar,DATEPART(MM,MMSTran.PostDateTime))))=6
			   Then (Convert(Varchar,DatePart(Year,MMSTran.PostDateTime))+'-0'+Convert(Varchar,DATEPART(MM,MMSTran.PostDateTime)))
			   Else (Convert(Varchar,DatePart(Year,MMSTran.PostDateTime))+'-'+Convert(Varchar,DATEPART(MM,MMSTran.PostDateTime)))
			   END FourDigitYearDashTwoDigitMonth,
	CASE When P.AssessAsDuesFlag = 1        ----- added RSP-435 EFT Draft Separation Project
	     Then 'Dues'
		 Else 'Products'
		 End TranProductCategory	
	from vMMSTran  MMSTran
    Join vTranItem TI
	   On MMSTran.MMSTranID = TI.MMSTranID
	Join vReportDimProduct DP
	   On TI.ProductID = DP.MMSProductID
	Join vProduct P
	   On TI.ProductID = P.ProductID
	Join vReasonCode R
	   On MMSTran.ReasonCodeID = R.ReasonCodeID
	Join vClub C
	   On C.ClubID = MMSTran.ClubID
	Where ValTranTypeID = 1  
	AND PostDateTime > @DraftDate   ---today’s EFT Draft date
	AND MMSTran.ReasonCodeID = 114   ----- "Recurrent Product Assessment"
	AND TranAmount > 0

 Order by PostDateTime,TranDate,MembershipID,  POSAmount, TranAmount 
end


Select 2 as id, tb.tranitemid, TB.MembershipID,TB.TranBalanceAmount as Amount,TI.ItemAmount as ProductAmount, TI.ItemSalesTax,
Case When TI.TranItemID IS Null AND TB.TranProductCategory='Dues'
     Then 'Dues'
	 When TI.TranItemID IS Null AND TB.TranProductCategory='Products'
     Then 'Products'
     Else DP.RevenueReportingDepartmentName
     End RevenueDepartment,
Case When TI.TranItemID IS Null
     Then 'Default'
     Else DP.RevenueProductGroupName
     End RevenueProductGroup,
DP.WorkdayCostCenter,  
Case When MMSTranClub.WorkdayRegion is null 
     Then MembershipClub.WorkdayRegion 
	 Else MMSTranClub.WorkdayRegion 
	 End WorkdayRegion,
Case When MMSTranClub.ClubID is null 
     Then MembershipClub.ClubID 
	 Else MMSTranClub.ClubID 
	 End ClubID,
Case When MMSTranClub.ValCurrencyCodeID is null 
     Then MembershipClub.ValCurrencyCodeID 
	 Else MMSTranClub.ValCurrencyCodeID 
	 End AS ValCurrencyCodeID,
Case When TI.TranItemID IS Null
     Then Convert(Varchar,'2000-01')
     Else (Case When Len((Convert(Varchar,DatePart(Year,MMSTran.PostDateTime))+'-'+Convert(Varchar,DATEPART(MM,MMSTran.PostDateTime))))=6
           Then (Convert(Varchar,DatePart(Year,MMSTran.PostDateTime))+'-0'+Convert(Varchar,DATEPART(MM,MMSTran.PostDateTime)))
           Else (Convert(Varchar,DatePart(Year,MMSTran.PostDateTime))+'-'+Convert(Varchar,DATEPART(MM,MMSTran.PostDateTime)))
           END )
     END FourDigitYearDashTwoDigitMonth,
TB.TranProductCategory                       ----- added RSP-435 EFT Draft Separation Project
INTO #TranBalanceRecords
From vTranBalance TB
Join #TodaysPayments TP
	On TB.MembershipID = TP.MembershipID
Left Join vTranItem TI
	On TI.TranItemID = TB.TranItemID
Left join vReportDimProduct DP
	On TI.ProductID = DP.MMSProductID
Left Join vMMSTran MMSTran 
	On TI.MMSTranID = MMSTran.MMSTranID 
Left Join vClub MMSTranClub
    On MMSTranClub.ClubID = MMSTran.ClubID
Join vMembership MS 
	On MS.MembershipID = TB.MembershipID
Join vClub MembershipClub
	On MembershipClub.ClubID = MS.ClubID
Where TranBalanceAmount > 0


Select id, MembershipID,Amount,ProductAmount, ItemSalesTax, ReasonCodeID,RevenueDepartment,RevenueProductGroup, 
WorkdayCostCenter, WorkdayRegion, ClubID, ValCurrencyCodeID,
FourDigitYearDashTwoDigitMonth,TranReason,TranProductCategory   ---- RSP-435 - added TranProductCategory
INTO #UnionedCharges
From #TodaysCharges
Union all
Select id, MembershipID,Amount,ProductAmount, ItemSalesTax,0 as ReasonCodeID,RevenueDepartment,RevenueProductGroup,
WorkdayCostCenter, WorkdayRegion, ClubID, ValCurrencyCodeID,
FourDigitYearDashTwoDigitMonth,'' as TranReason,TranProductCategory
From #TranBalanceRecords


Select Count(MembershipID) as RecordCount,MembershipID,TranProductCategory   ---- RSP-435 - added TranProductCategory
INTO #MembershipChargeCount
From #UnionedCharges
Group By MembershipID,TranProductCategory


Select 
TP.MembershipID, 
TP.MemberID,
convert(decimal(10,2),TP.TranAmount * #PlanRate.PlanRate) as TodaysPayment, 
convert(decimal(10,2),UC.Amount * #PlanRate.PlanRate) as AmountOwed, 
CASE when (UC.ProductAmount + UC.ItemSalesTax) = UC.Amount
          THEN UC.ProductAmount * #PlanRate.PlanRate
       WHEN ISNULL(UC.ProductAmount,0) = 0    ------- RSP-435 - updated - changed this to 0 not 1 because amount could be $1.00
          THEN 0  
       When (UC.ProductAmount + UC.ItemSalesTax) > UC.Amount
          THEN convert(decimal(10,2),(UC.Amount - UC.ItemSalesTax) * #PlanRate.PlanRate)
       ELSE convert(decimal(10,2),UC.ProductAmount * #PlanRate.PlanRate)
       END AdjustedOriginalTranProductAmount, -- Original transaction could have had a partial payment
	                                          -- so the amount is adjusted to match the payment. Amount owed can be more but on the 1st it should always match payment the payment.
CASE WHEN ISNULL(UC.ItemSalesTax,0) = 0     ------- RSP-435 - update -  changed this to 0 not 1 because tax could be $1.00
     THEN 0
       Else convert(decimal(10,2),UC.ItemSalesTax * #PlanRate.PlanRate)
       END OriginalTranProductTax,
UC.FourDigitYearDashTwoDigitMonth as ChargeMonth,
UC.RevenueDepartment,
UC.RevenueProductGroup,
UC.WorkdayCostCenter, 
UC.WorkdayRegion, 
IsNull(MCC.RecordCount,1) as MembershipRecordCount,
convert(decimal(10,4),(TP.TranAmount /IsNull(MCC.RecordCount,1)) * #PlanRate.PlanRate) as TodaysPaymentAllocation,
@ReportRunDateTime AS ReportRunDateTime,
MembershipClub.ClubID as MembershipClubID,
C.ClubName as MembershipClubName,
C.WorkdayRegion as MembershipWorkdayRegion,
UC.TranProductCategory                        ---- RSP-435 - added TranProductCategory

From 
	#TodaysPayments TP -- charges/assessments will not display if draft was not successfull
	Left Join  #UnionedCharges UC  
		On UC.MembershipID = TP.MembershipID
		AND TP.TranProductCategory = UC.TranProductCategory     ----- added RSP-435 EFT Draft Separation Project
	Left Join #MembershipChargeCount MCC
		On UC.MembershipID = MCC.MembershipID
	    AND UC.TranProductCategory = MCC.TranProductCategory     ----- added RSP-435 EFT Draft Separation Project
/********** Foreign Currency Stuff **********/
  JOIN vValCurrencyCode VCC
       ON UC.ValCurrencyCodeID = VCC.ValCurrencyCodeID
  JOIN #PlanRate
       ON VCC.CurrencyCode = #PlanRate.FromCurrencyCode     
/*******************************************/  

Join #Clubs MembershipClub  
     On MembershipClub.ClubID = TP.ClubID
Join vClub C
     On C.ClubID = MembershipClub.ClubID
Order by UC.MembershipID


Drop Table #TodaysPayments
Drop Table #TodaysCharges
Drop Table #TranBalanceRecords
Drop Table #UnionedCharges
Drop Table #MembershipChargeCount
Drop Table #PlanRate
Drop Table #tmpList
Drop Table #Clubs


END






