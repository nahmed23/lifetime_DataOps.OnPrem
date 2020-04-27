
CREATE PROC [dbo].[procCognos_SixtyDayTracker]  ----8/9/2017

AS
BEGIN 

SET XACT_ABORT ON
SET NOCOUNT ON


DECLARE @StartDate DATETIME
DECLARE @EndDate DATETIME
DECLARE @FirstOf3MonthsPrior DATETIME
DECLARE @FirstOfCurrentMonth DATETIME

SET @StartDate = '10/10/2017'
SET @EndDate = '11/30/2017'
SET @FirstOf3MonthsPrior = CONVERT(DATETIME,CONVERT(VARCHAR,DATEADD(m,-3, GETDATE()),110),110)
SET @FirstOfCurrentMonth = CONVERT(DATETIME,CONVERT(VARCHAR,GETDATE() - DAY(GETDATE()-1),110),110)
----Trans Detaiil-----
Select 
  Region.Description as Region
, Club.ClubCode
--, Trans.MemberID
, package.MemberID
--, package.PackageID
, P.Description
, Employee.ActiveStatusFlag as Employee
--, Item.TranItemID
, Item.ItemAmount
, CAST(Trans.PostDateTime as Date) PostDate
, Null as LtBucksPurchasers
, Null as SalesQuantity
, 'MMS' as SalesSource
--, Item.*

INTO #MMSTran
FROM vMMSTran Trans
JOIN vTranItem Item
   ON Item.MMSTranID = Trans.MMSTranID
JOIN vProduct P
  ON P.ProductID = Item.ProductID
JOIN vReportDimProduct DP 
  ON P.ProductID = DP.MMSProductID
JOIN vReportDimReportingHierarchy Hierarchy
  ON DP.DimReportingHierarchyKey = Hierarchy.DimReportingHierarchyKey
JOIN vClub Club
  ON Club.ClubID = Trans.ClubID
JOIN vValRegion Region
  ON Region.ValRegionID = Club.ValRegionID
LEFT JOIN vEmployee Employee
  ON Employee.MemberID = Trans.MemberID
JOIN vPackage package
  ON package.TranItemID = Item.TranItemID


WHERE Hierarchy.DimReportingHierarchyKey = 6509  --Weight Loss Challenges
AND CAST(Trans.PostDateTime as DATE) BETWEEN @StartDate AND @EndDate


-----Ecomm
--UNION

--Select 
--Region.Description as Region,
--Ecom.ClubCode,
--Ecom.MemberID,
--Ecom.ProductName,
--Employee.ActiveStatusFlag as Employee,
--Ecom.TotalAmount,
--Ecom.LTBucksPurchasers,
--Ecom.SalesQuantity,
--'Ecom' as SalesSource

--From TemporaryImport.dbo.SixtyDayEcom Ecom   ---Prod Location
----FROM Sandbox_Int.rep.SixtyDayEcom Ecom	---QA Location
--JOIN vClub Club
--  ON Club.ClubCode = Ecom.ClubCode
--JOIN vValRegion Region
--  ON Region.ValRegionID = Club.ValRegionID
--LEFT JOIN vEmployee Employee
--  ON Employee.MemberID = Ecom.MemberID
--  WHERE Ecom.CalendarDate BETWEEN @StartDate AND @EndDate
--  --AND Ecom.ClubCode Like 'ART%' 

/****Current PT Customer, Package purchased within last 3 months****/
CREATE TABLE #OldBusinessMembers (MemberID  INT, Amount DECIMAL(10,2),ABVAmount DECIMAL(10,2))
INSERT INTO #OldBusinessMembers (MemberID,Amount,ABVAmount)
SELECT MMSR.MemberID, 
       Sum(MMSR.ItemAmount),
       Sum(ABS(MMSR.ItemAmount))
  FROM vMMSRevenueReportSummary MMSR	---Prod Location
--  FROM Sandbox_Int.rep.OldBusiness MMSR    ---QA Location
  JOIN vReportDimProduct ReportDimProduct
    ON MMSR.ProductID = ReportDimProduct.MMSProductID
  JOIN vReportDimReportingHierarchy ReportDimReportingHierarchy
    ON ReportDimProduct.DimReportingHierarchyKey = ReportDimReportingHierarchy.DimReportingHierarchyKey
 WHERE ReportDimReportingHierarchy.DivisionName = 'Personal Training'  
   AND MMSR.PostDateTime >= @FirstOf3MonthsPrior
   AND MMSR.PostDateTime < @FirstOfCurrentMonth
   AND MMSR.EmployeeID <> -5 
   AND MMSR.ItemAmount <> 0 
 GROUP BY MMSR.MemberID


 -------------Results

SELECT C.Region
, C.ClubCode
, Goal.Target RegistrationTarget
--, COUNT(CASE WHEN C.Bucks = 1 THEN 1 ELSE NULL END) as BucksPurchasers
, COUNT(CASE WHEN C.Description like 'myLT%' THEN 1 Else NULL END) as BucksPurchasers   ---Only MMS
, COUNT(CASE WHEN C.Employee = 1 Then 1 Else Null End) as EmployeesActual
, COUNT(CASE WHEN C.Description LIKE '60 Day Challenge - Employ%' THEN 1 ELSE NULL END) as Employees
, COUNT(CASE WHEN OB.MemberID IS NOT NULL THEN 1 Else NULL END) as CurrentClientActual
, COUNT(CASE WHEN C.Description LIKE '60 Day Challenge - Current%' THEN 1 Else Null END) as CurrentClient
, COUNT(CAse WHEN OB.MemberID IS NULL Then 1 Else Null End) as NewClientActual
, COUNT(CASE WHEN C.Description LIKE '60 Day Challenge - New%' THEN 1 ELSE NULL END) as NewClient
, COUNT(*) as TotalRegistration
, Reservations.Registered as Reservations
, COUNT(*) / CAST(Goal.Target as Decimal(10,2)) as PercentOfTarget
, COUNT(CASE WHEN C.PostDate = GETDATE()-1 THEN 1 Else NULL END) as YesterdaysRegTotal
, Goal.Goal RegistrationDollarGoal
, SUM(C.ItemAmount) as TotalDollarAmount
, SUM(C.ItemAmount) / CAST(Goal.Goal as Decimal(10,2)) PercentOfGoal


FROM #MMSTran C
JOIN TemporaryImport.rep.SixtyDayGoals Goal   ---Prod Location
  ON Goal.Club = C.ClubCode
LEFT JOIN #OldBusinessMembers OB
  ON OB.MemberID = C.MemberID
LEFT JOIN 
  (SELECT COUNT(*) as Registered, r.clubcode 
   FROM TemporaryImport..SixtyDayWeighInsBoss r
   GROUP BY r.clubcode) as Reservations 
   ON reservations.clubcode = C.ClubCode

 GROUP BY c.Region, c.ClubCode, Goal.Target,  Goal.Goal, Reservations.Registered
 Order by c.Region, c.ClubCode


DROP TABLE #MMSTran
DROP TABLE #OldBusinessMembers


END
