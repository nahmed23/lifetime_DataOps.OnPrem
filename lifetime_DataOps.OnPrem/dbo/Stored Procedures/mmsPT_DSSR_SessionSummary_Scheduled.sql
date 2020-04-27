
CREATE PROC [dbo].[mmsPT_DSSR_SessionSummary_Scheduled]

AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

DECLARE @StartDate DATETIME
DECLARE	@ENDDate DATETIME

SET @StartDate = DATEADD(mm,DATEDIFF(mm,0,DATEADD(dd,-1,GETDATE())),0) -- First Day of yesterday's month
SET @ENDDate = CONVERT(DATETIME,CONVERT(VARCHAR,GETDATE(),110),110)  -- Today

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

SELECT MIN(S.PackageSessionID) FirstFitPoint_PackageSessionID,
       MS.MembershipID
  INTO #FirstMembershipFitPointSessionFree
  FROM dbo.vPackagesession S
  JOIN dbo.vClub RC
    ON S.Clubid = RC.Clubid
  JOIN dbo.vEmployee E
    ON S.Deliveredemployeeid = E.Employeeid
  JOIN dbo.vPackage PKG
    ON S.Packageid = PKG.Packageid
  JOIN vMMSTran MMST 
    ON MMST.MMSTranID = PKG.MMSTranID
  JOIN vMembership MS
    ON MS.MembershipID = MMST.MembershipID
 WHERE S.Delivereddatetime >= @StartDate 
   AND S.Delivereddatetime < @ENDDate
   AND PKG.Productid IN (2785, 3436)
 GROUP By MS.MembershipID
 ORDER by MS.MembershipID

SELECT MIN(S.PackageSessionID) FirstFitPoint_PackageSessionID,
       MS.MembershipID
  INTO #FirstMembershipFitPointSessionFreeDiamond
  FROM dbo.vPackagesession S
  JOIN dbo.vClub RC
    ON S.Clubid = RC.Clubid
  JOIN dbo.vEmployee E
    ON S.Deliveredemployeeid = E.Employeeid
  JOIN dbo.vPackage PKG
    ON S.Packageid = PKG.Packageid
  JOIN vMMSTran MMST 
    ON MMST.MMSTranID = PKG.MMSTranID
  JOIN vMembership MS
    ON MS.MembershipID = MMST.MembershipID
 WHERE S.Delivereddatetime >= @StartDate 
   AND S.Delivereddatetime < @ENDDate
   AND PKG.Productid IN (5445)
 GROUP By MS.MembershipID
 ORDER by MS.MembershipID

CREATE TABLE #DeliveredSessionsDetail	(
	StartDate DATETIME,
	ENDDate DATETIME,
	Clubid INT, 
	Clubname VARCHAR(50), 
	EmployeeID INT,
	ProductDeptID INT, 
	Productid INT,
	MembershipID INT,
	Delivereddatetime DATETIME,
    LocalCurrencyCode VARCHAR(15),
------------------------------------------------------	FitPoint columns	
	MembershipAgeInDaysAtDelivery2 INT,
	FitPointSessions_Today_LTBucks INT,	
	FitPointSessions_MTD_LTBucks INT,
	FitPointSessions_Today_Free INT,
	FitPointSessions_MTD_Free INT,
	FitPointSessions_Today_First30Days INT,
	FitPointSessions_MTD_First30Days INT,
    FitPointSessions_Today_FreeDiamond INT,
    FitPointSessions_MTD_FreeDiamond INT,
--New clumns QC#1742
    PTSessionDeliveredCount DECIMAL(4,1),
    LocalCurrency_PTSessionDeliveredValue DECIMAL(16,6),
    LocalCurrency_TotalSessionDeliveredValue DECIMAL(16,6))


INSERT INTO #DeliveredSessionsDetail
SELECT @StartDate,
       @ENDDate,
       RC.Clubid, 
       RC.Clubname, 
       MMST.EmployeeID,
       P.DepartmentID AS ProductDeptID, 
       P.Productid,
       MS.MembershipID,
       S.Delivereddatetime,
       LocalCurrencyCode.CurrencyCode as LocalCurrencyCode,
--	---------------------------------------FitPoint columns
       DATEDIFF(DAY, MS.CreatedDateTime, S.DeliveredDateTime) AS MembershipAgeInDaysAtDelivery2,
       CASE WHEN FMFPSF.FirstFitPoint_PackageSessionID Is Null THEN 0			--need to count only first session per membership
			ELSE CASE WHEN @ENDDate - S.Delivereddatetime <= 1 AND MMST.EmployeeID = -5 THEN 1
                      ELSE 0 END
       END AS FitPointSessions_Today_LTBucks,
       CASE WHEN FMFPSF.FirstFitPoint_PackageSessionID Is Null THEN 0				--need to count only first session per membership
			ELSE CASE WHEN MMST.EmployeeID = -5 THEN 1
                      ELSE 0 END
       END AS FitPointSessions_MTD_LTBucks,

       CASE WHEN FMFPSF.FirstFitPoint_PackageSessionID Is Null THEN 0				--need to count only first session per membership
			ELSE CASE WHEN @ENDDate - S.Delivereddatetime <= 1 AND MMST.EmployeeID <> -5 THEN 1
     				  ELSE 0 END
       END AS FitPointSessions_Today_Free,
       CASE WHEN FMFPSF.FirstFitPoint_PackageSessionID Is Null THEN	0			--need to count only first session per membership
			ELSE CASE WHEN MMST.EmployeeID <> -5 THEN 1
				      ELSE 0 END
	   END AS FitPointSessions_MTD_Free,
       CASE WHEN FMFPSF.FirstFitPoint_PackageSessionID Is Null THEN	0			--need to count only first session per membership
	  		ELSE CASE WHEN @ENDDate - S.Delivereddatetime <= 1 AND DATEDIFF(day, MS.CreatedDateTime, S.DeliveredDateTime) < 31 THEN 1
					  ELSE 0 END 
	   END AS FitPointSessions_Today_First30Days,
       CASE WHEN FMFPSF.FirstFitPoint_PackageSessionID Is Null THEN 0			--need to count only first session per membership
			ELSE CASE WHEN DATEDIFF(day, MS.CreatedDateTime, S.DeliveredDateTime) < 31 THEN 1
					  ELSE 0 END
	   END AS FitPointSessions_MTD_First30Days,
       CASE WHEN FMFPSD.FirstFitPoint_PackageSessionID Is Null THEN 0				--need to count only first session per membership
			ELSE CASE WHEN @ENDDate - S.Delivereddatetime <= 1 AND MMST.EmployeeID <> -5 THEN 1
     				  ELSE 0 END
	   END AS FitPointSessions_Today_Free,
       CASE WHEN FMFPSD.FirstFitPoint_PackageSessionID Is Null THEN 0    --need to count only first session per membership
			ELSE CASE WHEN MMST.EmployeeID <> -5 THEN 1
				      ELSE 0 END
	   END AS FitPointSessions_MTD_Free,
----New columns QC#1742
	  CASE WHEN DimProduct.ReportMTDAverageDeliveredSessionPriceFlag = 'Y'
	            THEN CASE WHEN P.Description LIKE '%30 minutes%'
	                           THEN 0.5
	                      ELSE 1 END
	       ELSE 0 END PTSessionDeliveredCount,
	  CASE WHEN DimProduct.ReportMTDAverageDeliveredSessionPriceFlag = 'Y'
	            THEN S.SessionPrice * LocalCurrencyPlanExchangeRate.PlanExchangeRate
	       ELSE 0 END LocalCurrency_PTSessionDeliveredValue,
	  S.SessionPrice * LocalCurrencyPlanExchangeRate.PlanExchangeRate LocalCurrency_TotalSessionDeliveredValue
  FROM dbo.vPackagesession S
  JOIN dbo.vClub RC
    ON S.Clubid = RC.Clubid
  JOIN dbo.vEmployee E
    ON S.Deliveredemployeeid = E.Employeeid
  JOIN dbo.vPackage PKG
    ON S.Packageid = PKG.Packageid
  JOIN dbo.vProduct P
    ON PKG.Productid = P.Productid
  JOIN vMMSTran MMST 
    ON MMST.MMSTranID = PKG.MMSTranID
  JOIN vMembership MS
    ON MS.MembershipID = MMST.MembershipID
  JOIN vReportDimProduct DimProduct --Join added 1/16 for conversion to DimReportingHierarchy
    ON P.ProductID = DimProduct.MMSProductID
  JOIN vReportDimReportingHierarchy DimReportingHierarchy --Join added 1/16 for conversion to DimReportingHierarchy
    ON DimProduct.DimReportingHierarchyKey = DimReportingHierarchy.DimReportingHierarchyKey
  LEFT JOIN #FirstMembershipFitPointSessionFree FMFPSF
    ON S.PackageSessionID = FMFPSF.FirstFitPoint_PackageSessionID
  LEFT JOIN #FirstMembershipFitPointSessionFreeDiamond FMFPSD
    ON S.PackageSessionID = FMFPSD.FirstFitPoint_PackageSessionID
/*********** Foreign Currency ***************/
  JOIN vValCurrencyCode OriginalCurrencyCode  
    ON ISNULL(MMST.ValCurrencyCodeID,1) = OriginalCurrencyCode.ValCurrencyCodeID 
  JOIN vValCurrencyCode LocalCurrencyCode 
    ON RC.ValCurrencyCodeID = LocalCurrencyCode.ValCurrencyCodeID 
  JOIN vPlanExchangeRate LocalCurrencyPlanExchangeRate
    ON OriginalCurrencyCode.CurrencyCode = LocalCurrencyPlanExchangeRate.FromCurrencyCode
   AND LocalCurrencyCode.CurrencyCode = LocalCurrencyPlanExchangeRate.ToCurrencyCode
   AND YEAR(@StartDate) = LocalCurrencyPlanExchangeRate.PlanYear
 WHERE S.Delivereddatetime >= @StartDate 
   AND S.Delivereddatetime < @ENDDate
   AND P.DepartmentID in (9,19) --Removed 33 5/4/2011 BSD
ORDER BY RC.Clubid, MS.MembershipID, S.Delivereddatetime --MMST.EmployeeID, P.Productid


CREATE TABLE #DeliveredSessionsDetailByClubMembership	(
	Clubid INT, 
	Clubname VARCHAR(50), 
	MembershipID INT,
    LocalCurrencyCode VARCHAR(15),
------------------------------------------------------	FitPoint columns	
	FitPointSessions_Today_LTBucks INT,	
	FitPointSessions_MTD_LTBucks INT,
	FitPointSessions_Today_Free INT,
	FitPointSessions_MTD_Free INT,
	FitPointSessions_Today_First30Days INT,
	FitPointSessions_MTD_First30Days INT,
    FitPointSessions_Today_FreeDiamond INT,
    FitPointSessions_MTD_FreeDiamond INT,
--New clumns QC#1742
    PTSessionDeliveredCount DECIMAL(4,1),
    LocalCurrency_PTSessionDeliveredValue DECIMAL(16,6),
    LocalCurrency_TotalSessionDeliveredValue DECIMAL(16,6))

INSERT INTO #DeliveredSessionsDetailByClubMembership
SELECT ClubID,
       ClubName,
       MembershipID,
       LocalCurrencyCode,
       MAX(FitPointSessions_Today_LTBucks) as FitPointSessions_Today_LTBucks,
       MAX(FitPointSessions_MTD_LTBucks) as FitPointSessions_MTD_LTBucks,
       MAX(FitPointSessions_Today_Free) as FitPointSessions_Today_Free,
       MAX(FitPointSessions_MTD_Free) as FitPointSessions_MTD_Free,
       MAX(FitPointSessions_Today_First30Days) as FitPointSessions_Today_First30Days,
       MAX(FitPointSessions_MTD_First30Days) as FitPointSessions_MTD_First30Days,
       MAX(FitPointSessions_Today_FreeDiamond) as FitPointSessions_Today_FreeDiamond,
       MAX(FitPointSessions_MTD_FreeDiamond) as FitPointSessions_MTD_FreeDiamond,
       SUM(PTSessionDeliveredCount) as PTSessionDeliveredCount,
       SUM(LocalCurrency_PTSessionDeliveredValue) as LocalCurrency_PTSessionDeliveredValue,
       SUM(LocalCurrency_TotalSessionDeliveredValue) as LocalCurrency_TotalSessionDeliveredValue
  FROM #DeliveredSessionsDetail
 GROUP by ClubID,ClubName,MembershipID,LocalCurrencyCode
 ORDER by ClubID,MembershipID

SELECT Clubid,
       Clubname, 
       LocalCurrencyCode,
       SUM(CASE WHEN FitPointSessions_Today_LTBucks >= 1 THEN 1	ELSE 0 END) [FitPointSessions_Today_LTBucks],
       SUM(CASE WHEN FitPointSessions_MTD_LTBucks >= 1 THEN 1 ELSE 0 END)  [FitPointSessions_MTD_LTBucks],
       SUM(CASE WHEN FitPointSessions_Today_Free >= 1 THEN 1 ELSE 0 END) [FitPointSessions_Today_Free],
       SUM(CASE WHEN FitPointSessions_MTD_Free >= 1 THEN 1 ELSE 0 END) [FitPointSessions_MTD_Free],
       SUM(CASE WHEN FitPointSessions_Today_First30Days >= 1 THEN 1 ELSE 0 END) [FitPointSessions_Today_First30Days],
       SUM(CASE WHEN FitPointSessions_MTD_First30Days >= 1 THEN 1 ELSE 0 END) [FitPointSessions_MTD_First30Days],
       SUM(CASE WHEN FitPointSessions_Today_FreeDiamond >= 1 THEN 1 ELSE 0 END) [FitPointSessions_Today_FreeDiamond],
       SUM(CASE WHEN FitPointSessions_MTD_FreeDiamond >= 1 THEN 1 ELSE 0 END) [FitPointSessions_MTD_FreeDiamond],
       USDPlanExchangeRate.PlanExchangeRate PlanRate,
       SUM(PTSessionDeliveredCount) PTSessionDeliveredCount,
       SUM(LocalCurrency_PTSessionDeliveredValue) LocalCurrency_PTSessionDeliveredValue,
       SUM(LocalCurrency_TotalSessionDeliveredValue) LocalCurrency_TotalSessionDeliveredValue,
       SUM(LocalCurrency_PTSessionDeliveredValue * USDPlanExchangeRate.PlanExchangeRate) USD_PTSessionDeliveredValue,
       SUM(LocalCurrency_TotalSessionDeliveredValue * USDPlanExchangeRate.PlanExchangeRate) USD_TotalSessionDeliveredValue
  FROM #DeliveredSessionsDetailByClubMembership
  JOIN vPlanExchangeRate USDPlanExchangeRate
    ON #DeliveredSessionsDetailbyClubMembership.LocalCurrencyCode = USDPlanExchangeRate.FromCurrencyCode
   AND 'USD' = USDPlanExchangeRate.ToCurrencyCode
   AND YEAR(@StartDate) = USDPlanExchangeRate.PlanYear
 GROUP BY Clubid, Clubname, LocalCurrencyCode, USDPlanExchangeRate.PlanExchangeRate
 ORDER BY Clubid

DROP TABLE #DeliveredSessionsDetail
DROP TABLE #DeliveredSessionsDetailByClubMembership
DROP TABLE #FirstMembershipFitPointSessionFree
DROP TABLE #FirstMembershipFitPointSessionFreeDiamond

-- Report Logging
  UPDATE HyperionReportLog
  SET ENDDateTime = getdate()
  WHERE ReportLogID = @Identity

END
