



-- EXEC mmsCommissionableSales_chart 'Apr 1, 2011', 'Apr 11, 2011', 'New Hope, MN'

CREATE  PROC [dbo].[mmsCommissionableSales_chart] (
  @PostStartDate SMALLDATETIME,
  @PostEndDate SMALLDATETIME,
  @ClubName VARCHAR(50)
  )
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Returns recordset from mmstran used for a chart in the CommissionableSales Brio bqy
--
-- Parameters: A start and end post date
--     A single Clubname
--     a list of departments (| separated) 
--
-- 06/04/2010 MLL Add Automated Refund Transaction Handling

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY


/********  Foreign Currency Stuff ********/
DECLARE @ReportingCurrencyCode VARCHAR(15)
SET @ReportingCurrencyCode = 
(SELECT CASE WHEN COUNT(DISTINCT C.ValCurrencyCodeID) >=2 THEN 'USD' ELSE MAX(VCC.CurrencyCode) END AS ReportingCurrency
  FROM vClub C    
  JOIN vValCurrencyCode VCC ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID
WHERE C.ClubName = @ClubName)

CREATE TABLE #PlanRate (PlanRate DECIMAL(14,4), FromCurrencyCode VARCHAR(15), PlanYear INT)
INSERT INTO #PlanRate
SELECT PlanExchangeRate, FromCurrencyCode, PlanYear
FROM PlanExchangeRate
WHERE PlanYear >= Year(@PostStartDate)
  AND PlanYear <= Year(@PostEndDate)
  AND ToCurrencyCode = @ReportingCurrencyCode

CREATE TABLE #ToUSDPlanRate (PlanRate DECIMAL(14,4), FromCurrencyCode VARCHAR(15), PlanYear INT)
INSERT INTO #ToUSDPlanRate
SELECT PlanExchangeRate, FromCurrencyCode, PlanYear
FROM PlanExchangeRate
WHERE PlanYear >= Year(@PostStartDate)
  AND PlanYear <= Year(@PostEndDate)
  AND ToCurrencyCode = 'USD'
/***************************************/

IF @PostStartDate >= (SELECT MIN(PostDateTime) FROM dbo.vMMSCommissionableSalesSummary)
BEGIN

SELECT CSS.ClubName, CSS.SalesPersonFirstName, CSS.SalesPersonLastName,CSS.SalesEmployeeID, 
       ((CSS.ItemAmount * #PlanRate.PlanRate)  /CSS.CommissionCount) AS CommSaleAmount,
	   (CSS.ItemAmount /CSS.CommissionCount) AS LocalCurrency_CommSaleAmount,
	   ((CSS.ItemAmount * #ToUSDPlanRate.PlanRate) /CSS.CommissionCount) AS USD_CommSaleAmount,
	   DATEPART(year,CSS.PostDateTime) AS Year,
       DATEPART(month,CSS.PostDateTime) AS Month,CSS.DeptDescription, CSS.ProductDescription, 
       CSS.ProductID,CSS.AdvisorID,CSS.AdvisorFirstName,CSS.AdvisorLastName,
     CASE
       WHEN MS.CreatedDateTime Is Null
        THEN CSS.SalesEmployeeID
       WHEN DATEDIFF(d,MS.CreatedDateTime,CSS.PostDateTime)<=3
            AND CSS.ProductID = 88
       THEN CSS.AdvisorID
       ELSE CSS.SalesEmployeeID
       END CommReportEmployeeID,
/******  Foreign Currency Stuff  *********/
	   VCC.CurrencyCode as LocalCurrencyCode,
       #PlanRate.PlanRate,
       @ReportingCurrencyCode as ReportingCurrencyCode   	
/***************************************/

  FROM dbo.vMMSCommissionableSalesSummary CSS
  JOIN vMember M
       ON M.MemberID = CSS.MemberID
  JOIN vMembership MS
       ON MS.MembershipID = M.MembershipID    
/********** Foreign Currency Stuff **********/
  JOIN vClub C
	   ON CSS.ClubID = C.ClubID
  JOIN vValCurrencyCode VCC
       ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID
  JOIN #PlanRate
       ON VCC.CurrencyCode = #PlanRate.FromCurrencyCode
      AND YEAR(CSS.PostDateTime) = #PlanRate.PlanYear
  JOIN #ToUSDPlanRate
       ON VCC.CurrencyCode = #ToUSDPlanRate.FromCurrencyCode
      AND YEAR(CSS.PostDateTime) = #ToUSDPlanRate.PlanYear
/*******************************************/

  
 WHERE CSS.PostDateTime >= @PostStartDate AND
       CSS.PostDateTime < @PostEndDate AND
       CSS.ClubName = @ClubName

END
ELSE
	 BEGIN

--Populate temporary table with Automated Refunds

SELECT 
       CASE MMST.ReasonCodeID
            WHEN 108
                 THEN MembershipClub.ClubName
                 ELSE OriginalTranClub.ClubName
       END AS ClubName,
       TI.ItemAmount,
       DATEPART (year, MMST.PostDateTime) Year, 
       DATEPART (month,MMST.PostDateTime) Month,
       D.Description AS DeptDescription,
       P.Description AS ProductDescription,
       P.ProductID,
       MIN(SC.SaleCommissionID) AS PrimarySalesPersonSalesCommissionID,
       MMST.ReceiptNumber, 
       TI.TranItemID,
       MMST.PostDateTime, 
       MS.CreatedDateTime AS MembershipCreatedDate,
       MembershipAdvisor.EmployeeID AS AdvisorID, 
       MembershipAdvisor.FirstName AS AdvisorFirstName, 
       MembershipAdvisor.LastName AS AdvisorLastName

INTO #AutomatedRefundDetail
  FROM vMMSTran MMST
  JOIN vTranItem TI
    ON MMST.MMSTranID = TI.MMSTranID
  JOIN vProduct P
    ON TI.ProductID = P.ProductID
  JOIN vTranItemRefund TIR
    ON TIR.TranItemID = TI.TranItemID
  JOIN vTranItem OriginalTI
    ON OriginalTI.TranItemID = TIR.OriginalTranItemID
  JOIN vSaleCommission SC
    ON OriginalTI.TranItemID = SC.TranItemID
  JOIN vMMSTran OriginalMMST
    ON OriginalMMST.MMSTranID = OriginalTI.MMSTranID
  JOIN vClub OriginalTranClub
    ON OriginalTranClub.ClubID = OriginalMMST.ClubID
  JOIN vValRegion OriginalRegion
    ON OriginalRegion.ValRegionID = OriginalTranClub.ValRegionID
  JOIN vMembership MS
    ON MS.MembershipID = MMST.MembershipID
  JOIN vClub MembershipClub
    ON MembershipClub.ClubID = MS.ClubID
  JOIN vValRegion MembershipRegion
    ON MembershipRegion.ValRegionID = MembershipClub.ValRegionID
  LEFT JOIN vCompany CO
    ON CO.CompanyID = MS.CompanyID
  JOIN vMembershipType MT
    ON MT.MembershipTypeID = MS.MembershipTYpeID
  JOIN vProduct MSP
    ON MSP.ProductID = MT.ProductID
  JOIN vMember OriginalM
    ON OriginalM.MemberID = OriginalMMST.MemberID
  LEFT JOIN vEmployee MembershipAdvisor
    ON MembershipAdvisor.EmployeeID = MS.AdvisorEmployeeID
  JOIN vDepartment D
    ON D.DepartmentID = P.DepartmentID
 WHERE MMST.PostDateTime >= @PostStartDate 
   AND MMST.PostDateTime < @PostEndDate
   AND MMST.TranVoidedID IS NULL
   AND MMST.ValTranTypeID = 5
   AND CASE MMST.ReasonCodeID
            WHEN 108
                 THEN MembershipClub.ClubName
                 ELSE OriginalTranClub.ClubName
       END = @ClubName
 GROUP BY 
       CASE MMST.ReasonCodeID
            WHEN 108
                 THEN MembershipClub.ClubName
                 ELSE OriginalTranClub.ClubName
       END,
       TI.ItemAmount,	   
       DATEPART (year, MMST.PostDateTime),
       DATEPART (month,MMST.PostDateTime),
       D.Description,
       P.Description,
       P.ProductID,
       MMST.ReceiptNumber, 
       TI.TranItemID,
       MMST.PostDateTime, 
       MS.CreatedDateTime,
       MembershipAdvisor.EmployeeID, 
       MembershipAdvisor.FirstName, 
       MembershipAdvisor.LastName

--Find transactions that fall outside of the table (non-Automated Refund)

SELECT C.ClubName, E.FirstName SalesPersonFirstName, E.LastName SalesPersonLastName, E.EmployeeID SalesEmployeeID,
	   ((TI.ItemAmount * #PlanRate.PlanRate) / CSC.CommissionCount ) as CommSaleAmount,
	   ( TI.ItemAmount / CSC.CommissionCount ) as LocalCurrency_CommSaleAmount,
	   ((TI.ItemAmount * #ToUSDPlanRate.PlanRate) / CSC.CommissionCount ) as USD_CommSaleAmount,
       DATEPART (year, MMST.PostDateTime) Year, DATEPART (month,MMST.PostDateTime) Month,
	   D.Description DeptDescription, P.Description ProductDescription,p.productid,
	   E2.EmployeeID AdvisorID,E2.FirstName AdvisorFirstName, E2.LastName AdvisorLastName,
     CASE
       WHEN MS.CreatedDateTime Is Null
        THEN E.EmployeeID
       WHEN DATEDIFF(d,MS.CreatedDateTime,MMST.PostDateTime)<=3
            AND TI.ProductID = 88
       THEN E2.EmployeeID
       ELSE E.EmployeeID
       END CommReportEmployeeID,
/******  Foreign Currency Stuff  *********/
	   VCC.CurrencyCode as LocalCurrencyCode,
       #PlanRate.PlanRate,
       @ReportingCurrencyCode as ReportingCurrencyCode  	   	
/***************************************/
  FROM dbo.vMMSTran MMST
  JOIN dbo.vTranItem TI
      ON MMST.MMSTranID = TI.MMSTranID
  JOIN dbo.vMembership MS
	       ON MS.MembershipID = MMST.MembershipID
  JOIN dbo.vProduct P
      ON TI.ProductID = P.ProductID
  JOIN dbo.vSaleCommission SC
       ON TI.TranItemID = SC.TranItemID
  JOIN dbo.vEmployee E
      ON SC.EmployeeID = E.EmployeeID
  JOIN dbo.vCommissionSplitCalc CSC
       ON TI.TranItemID = CSC.TranItemID
  JOIN dbo.vDepartment D
       ON P.DepartmentID = D.DepartmentID
  JOIN dbo.vClub C 
       ON C.ClubID = MMST.ClubID
/********** Foreign Currency Stuff **********/
  JOIN vValCurrencyCode VCC
       ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID
  JOIN #PlanRate
       ON VCC.CurrencyCode = #PlanRate.FromCurrencyCode
      AND YEAR(MMST.PostDateTime) = #PlanRate.PlanYear
  JOIN #ToUSDPlanRate
       ON VCC.CurrencyCode = #ToUSDPlanRate.FromCurrencyCode
      AND YEAR(MMST.PostDateTime) = #ToUSDPlanRate.PlanYear
/*******************************************/
  LEFT JOIN dbo.vEmployee E2
		   ON MS.AdvisorEmployeeID = E2.EmployeeID
 WHERE MMST.TranVoidedID IS NULL AND
       MMST.PostDateTime >= @PostStartDate AND
       MMST.PostDateTime < @PostEndDate AND
       C.ClubName = @ClubName

UNION ALL
--Find transactions that fall outside of the table (Automated Refund)
SELECT ARD.ClubName,
       E.FirstName AS SalesPersonFirstName,
       E.LastName AS SalesPersonLastName,
       E.EmployeeID AS SalesEmployeeID,
       ARD.CommSaleAmount * #PlanRate.PlanRate as CommSaleAmount,
	   ARD.CommSaleAmount as LocalCurrency_CommSaleAmount,
	   ARD.CommSaleAmount * #ToUSDPlanRate.PlanRate as USD_CommSaleAmount,
       ARD.Year,
       ARD.Month,
       ARD.DeptDescription,
       ARD.ProductDescription,
       ARD.ProductID,
       ARD.AdvisorID,
       ARD.AdvisorFirstName,
       ARD.AdvisorLastName,
       CASE 
            WHEN ARD.MembershipCreatedDate IS NULL
                 THEN E.EmployeeID
            WHEN DATEDIFF(d,ARD.MembershipCreatedDate, ARD.PostDateTime)<=3 AND ARD.ProductID = 88
                 THEN ARD.AdvisorID
            ELSE E.EmployeeID
       END CommReportEmployeeID,
/******  Foreign Currency Stuff  *********/
	   VCC.CurrencyCode as LocalCurrencyCode,
       #PlanRate.PlanRate,
       @ReportingCurrencyCode as ReportingCurrencyCode  	   	
/***************************************/

  FROM #AutomatedRefundDetail ARD
  JOIN vSaleCommission SC
    ON SC.SaleCommissionID = ARD.PrimarySalesPersonSalesCommissionID
  JOIN vEmployee E
    on E.EmployeeID = SC.EmployeeID
/********** Foreign Currency Stuff **********/
  JOIN vClub C
	   ON ARD.ClubName = C.ClubName
  JOIN vValCurrencyCode VCC
       ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID
  JOIN #PlanRate
       ON VCC.CurrencyCode = #PlanRate.FromCurrencyCode
      AND YEAR(ARD.PostDateTime) = #PlanRate.PlanYear
  JOIN #ToUSDPlanRate
       ON VCC.CurrencyCode = #ToUSDPlanRate.FromCurrencyCode
      AND YEAR(ARD.PostDateTime) = #ToUSDPlanRate.PlanYear
/*******************************************/

DROP TABLE #AutomatedRefundDetail

END

DROP TABLE #PlanRate
DROP TABLE #ToUSDPlanRate

-- Report Logging
UPDATE HyperionReportLog
SET EndDateTime = getdate()
WHERE ReportLogID = @Identity

END

