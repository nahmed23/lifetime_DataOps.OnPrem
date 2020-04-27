



CREATE PROC [dbo].[procCognos_PT_DSSR_SessionStatisticsByClub] 

AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON


DECLARE @StartDate AS DATETIME
DECLARE @ENDDate AS DATETIME
DECLARE @ReportDate AS DATETIME
DECLARE @ReportRunDateTime AS DATETIME
DECLARE @ReportDateDayOfMonth as INT

SET @StartDate = CONVERT(DATETIME,CONVERT(VARCHAR,(GETDATE() - DAY(GETDATE()-1)),110),110)
SET @ENDDate = CONVERT(DATETIME,CONVERT(VARCHAR,GETDATE(),110),110)
SET @ReportRunDateTime = Replace(Substring(convert(varchar,getdate(),100),1,6)+', '+Substring(convert(varchar,GETDATE(),100),8,10)+' '+Substring(convert(varchar,getdate(),100),18,2),'  ',' ')
SET @ReportDate = Replace(Substring(convert(varchar,(getdate()-1),100),1,6)+', '+Substring(convert(varchar,(GETDATE()-1),100),8,4),'  ',' ')
SET @ReportDateDayOfMonth = Day(getdate()-1)

Select 
PostingRegionDescription,PostingClubName,PostingClubid,
CASE WHEN ReportDimProduct.CorporateTransferFlag = 'Y' 
     THEN MMSR.Quantity * ReportDimProduct.CorporateTransferMultiplier 
     ELSE MMSR.ItemAmount 
        END * USDPlanExchangeRate.PlanExchangeRate as ItemAmount,
CASE WHEN ReportDimProduct.CorporateTransferFlag = 'Y' 
     THEN MMSR.Quantity * ReportDimProduct.CorporateTransferMultiplier 
     ELSE MMSR.ItemAmount 
        END LocalCurrency_ItemAmount,
@ReportDate ReportDate,
P.PackageProductFlag,
USDPlanExchangeRate.PlanExchangeRate PlanRate,
ReportDimProduct.CorporateTransferFlag,
ReportDimProduct.CorporateTransferMultiplier
INTO #Detail
FROM vMMSRevenueReportSummary MMSR 
  JOIN vProduct P 
    ON P.ProductID = MMSR.ProductID
  JOIN vReportDimProduct ReportDimProduct 
    ON MMSR.ProductID = ReportDimProduct.MMSProductID
  JOIN vReportDimReportingHierarchy ReportDimReportingHierarchy 
    ON ReportDimProduct.DimReportingHierarchyKey = ReportDimReportingHierarchy.DimReportingHierarchyKey
  JOIN vClub C 
    ON MMSR.PostingClubID = C.ClubID
  JOIN vPlanExchangeRate USDPlanExchangeRate
    ON ISNULL(MMSR.LocalCurrencyCode,'USD') = USDPlanExchangeRate.FromCurrencyCode
   AND 'USD' = USDPlanExchangeRate.ToCurrencyCode
   AND YEAR(MMSR.PostDateTime) = USDPlanExchangeRate.PlanYear
  JOIN vTranItem TI
    ON MMSR.TranItemID = TI.TranItemID

WHERE MMSR.PostDateTime >= @StartDate 
   AND MMSR.PostDateTime < @ENDDate
   AND P.PackageProductFlag = 1
   AND ReportDimReportingHierarchy.DivisionName = 'Personal Training'  ----- Confirmed: the division "Personal Training" contains Product DepartmentIDs 9 & 19
   And (MMSR.ItemAmount <> 0 
        OR (MMSR.ItemAmount = 0 AND MMSR.EmployeeID = -5) 
        OR (MMSR.ItemAmount = 0 AND ReportDimProduct.CorporateTransferFlag = 'Y')) 


Select PostingClubID,PostingRegionDescription, PostingClubName,ReportDate, Sum(ItemAmount) as Accum_PkgSales_ByClub, 
Sum(LocalCurrency_ItemAmount) as LocalCurrency_Accum_PkgSales_ByClub
Into #PkgSaleSummaryByClub
from #Detail
Group By PostingRegionDescription, PostingClubName, PostingClubID, ReportDate


Select 
C.Clubid, 
C.Clubname,
Sum(CASE WHEN DimProduct.ReportMTDAverageDeliveredSessionPriceFlag = 'Y'
       THEN CASE WHEN P.Description LIKE '%30 minutes%'
                  THEN 0.5
                  ELSE 1 
             END
       ELSE 0 
        END)  PTSessionDeliveredCount,
Sum(CASE WHEN DimProduct.ReportMTDAverageDeliveredSessionPriceFlag = 'Y'
       THEN S.SessionPrice * USDPlanExchangeRate.PlanExchangeRate
       ELSE 0 
        END) USD_PTSessionDeliveredValue,
Sum(CASE WHEN DimProduct.ReportMTDAverageDeliveredSessionPriceFlag = 'Y'
       THEN S.SessionPrice
       ELSE 0 
        END) LocalCurrency_PTSessionDeliveredValue,
LocalCurrencyCode.CurrencyCode,
USDPlanExchangeRate.FromCurrencyCode,
USDPlanExchangeRate.ToCurrencyCode
INTO #SessionDeliveredSummaryByClub
FROM vPackagesession S
  JOIN vClub C
    ON S.Clubid = C.Clubid
  JOIN vPackage PKG
    ON S.Packageid = PKG.Packageid
  JOIN vProduct P
    ON PKG.Productid = P.Productid
  JOIN vReportDimProduct DimProduct 
    ON P.ProductID = DimProduct.MMSProductID
  JOIN vReportDimReportingHierarchy DimReportingHierarchy 
    ON DimProduct.DimReportingHierarchyKey = DimReportingHierarchy.DimReportingHierarchyKey
/*********** Foreign Currency ***************/
  JOIN vMMSTran MMST 
    ON MMST.MMSTranID = PKG.MMSTranID
  JOIN vValCurrencyCode OriginalCurrencyCode  
    ON ISNULL(MMST.ValCurrencyCodeID,1) = OriginalCurrencyCode.ValCurrencyCodeID 
  JOIN vValCurrencyCode LocalCurrencyCode 
    ON C.ValCurrencyCodeID = LocalCurrencyCode.ValCurrencyCodeID 
  JOIN vPlanExchangeRate USDPlanExchangeRate
    ON LocalCurrencyCode.CurrencyCode = USDPlanExchangeRate.FromCurrencyCode
          AND 'USD' = USDPlanExchangeRate.ToCurrencyCode
       AND YEAR(@StartDate) = USDPlanExchangeRate.PlanYear
WHERE S.Delivereddatetime >= @StartDate 
   AND S.Delivereddatetime < @ENDDate
   AND P.DepartmentID in (9,19) 
Group By C.Clubid,C.Clubname,LocalCurrencyCode.CurrencyCode,USDPlanExchangeRate.FromCurrencyCode,USDPlanExchangeRate.ToCurrencyCode


Select Area.[Description] as PTRCLArea, 
C.Clubid, 
C.ClubName,
IsNull(Delivered.PTSessionDeliveredCount,0) as DeliveredSessionsCount, 
------IsNull(Delivered.USD_PTSessionDeliveredValue,0) as DeliveredSessionsValue,   ---- REP-161 Always return values in Local Currency
IsNull(Delivered.LocalCurrency_PTSessionDeliveredValue,0) as DeliveredSessionsValue,
IsNull(Delivered.LocalCurrency_PTSessionDeliveredValue,0) as LocalCurrency_DeliveredSessionsValue,
/*
Case When (IsNull(Delivered.PTSessionDeliveredCount,0) = 0 OR Delivered.PTSessionDeliveredCount = 0)   ----- REP-161
     THEN 0
       When (IsNull(Delivered.USD_PTSessionDeliveredValue,0) = 0 OR Delivered.USD_PTSessionDeliveredValue = 0)
       Then 0
       Else Delivered.USD_PTSessionDeliveredValue / Delivered.PTSessionDeliveredCount
       END AvgDeliveredSessionValue,
*/
Case When (IsNull(Delivered.PTSessionDeliveredCount,0) = 0 OR Delivered.PTSessionDeliveredCount = 0)
     THEN 0
       When (IsNull(Delivered.LocalCurrency_PTSessionDeliveredValue,0) = 0 OR Delivered.LocalCurrency_PTSessionDeliveredValue = 0)
       Then 0
       Else Delivered.LocalCurrency_PTSessionDeliveredValue / Delivered.PTSessionDeliveredCount
       END AvgDeliveredSessionValue,
Case When (IsNull(Delivered.PTSessionDeliveredCount,0) = 0 OR Delivered.PTSessionDeliveredCount = 0)
     THEN 0
       When (IsNull(Delivered.LocalCurrency_PTSessionDeliveredValue,0) = 0 OR Delivered.LocalCurrency_PTSessionDeliveredValue = 0)
       Then 0
       Else Delivered.LocalCurrency_PTSessionDeliveredValue / Delivered.PTSessionDeliveredCount
       END LocalCurrency_AvgDeliveredSessionValue,
-------IsNull(Accum_PkgSales_ByClub,0) as PackageProductSales,   --- REP-161
IsNull(LocalCurrency_Accum_PkgSales_ByClub,0) as PackageProductSales,
IsNull(LocalCurrency_Accum_PkgSales_ByClub,0) as LocalCurrency_PackageProductSales,
/*
Case When (IsNull(Accum_PkgSales_ByClub,0) = 0 or Accum_PkgSales_ByClub = 0)   ---- REP-161
     Then 0
       When (IsNull(Delivered.USD_PTSessionDeliveredValue,0) = 0 OR Delivered.USD_PTSessionDeliveredValue = 0)
       Then 0
       Else Delivered.USD_PTSessionDeliveredValue/Accum_PkgSales_ByClub
       END DeliveredToSoldPercentage,
*/
Case When (IsNull(LocalCurrency_Accum_PkgSales_ByClub,0) = 0 or LocalCurrency_Accum_PkgSales_ByClub = 0)
     Then 0
       When (IsNull(Delivered.LocalCurrency_PTSessionDeliveredValue,0) = 0 OR Delivered.LocalCurrency_PTSessionDeliveredValue = 0)
       Then 0
       Else Delivered.LocalCurrency_PTSessionDeliveredValue/LocalCurrency_Accum_PkgSales_ByClub
       END DeliveredToSoldPercentage,
Case When (IsNull(LocalCurrency_Accum_PkgSales_ByClub,0) = 0 or LocalCurrency_Accum_PkgSales_ByClub = 0)
     Then 0
       When (IsNull(Delivered.LocalCurrency_PTSessionDeliveredValue,0) = 0 OR Delivered.LocalCurrency_PTSessionDeliveredValue = 0)
       Then 0
       Else Delivered.LocalCurrency_PTSessionDeliveredValue/LocalCurrency_Accum_PkgSales_ByClub
       END LocalCurrency_DeliveredToSoldPercentage,
@ReportRunDateTime as ReportRunDateTime,
@ReportDate as ReportDate,
@ReportDateDayOfMonth as ReportDateDayOfMonth
From vClub C
Join vValPTRCLArea Area
On C.ValPTRCLAreaID = Area.ValPTRCLAreaID
Left Join #PkgSaleSummaryByClub Sales
On C.ClubID = Sales.PostingClubID
Left Join #SessionDeliveredSummaryByClub Delivered
On C.ClubID = Delivered.ClubID


Drop Table #Detail
Drop Table #PkgSaleSummaryByClub
Drop Table #SessionDeliveredSummaryByClub

END




