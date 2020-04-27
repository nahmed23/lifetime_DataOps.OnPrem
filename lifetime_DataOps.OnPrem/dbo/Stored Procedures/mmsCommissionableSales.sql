





CREATE       PROC [dbo].[mmsCommissionableSales] (
  @PostStartDate SMALLDATETIME,
  @PostEndDate SMALLDATETIME,
  @ClubName VARCHAR(2000),
  @DeptList VARCHAR(1000)
  )
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

--
-- Returns recordset from vMMSCommissionableSalesSummary used for commissions reporting
--
-- Parameters: A start and end post date
--     A list of Clubnames ( | separated )
--     a list of departments (| separated) 
--
--  Exec mmsCommissionableSales 'Apr 1, 2011','Apr 11, 2011','New Hope, MN', 'Personal Training'
-- 06/04/2010 MLL Add Automated Refund Transaction Handling
-- 06/29/2010 MLL Added ItemDiscountAmount to result set

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

CREATE TABLE #tmpList (StringField VARCHAR(50))
CREATE TABLE #Depts (DeptName VARCHAR(50))
IF @DeptList <> 'All'
  BEGIN
  --INSERT INTO #Depts EXEC procParseStringList @DeptList
   EXEC procParseStringList @DeptList
   INSERT INTO #Depts (DeptName) SELECT StringField FROM #tmpList
   TRUNCATE TABLE #tmpList
  END
  ELSE
  BEGIN
     INSERT INTO #Depts VALUES('All') 
  END

CREATE TABLE #Clubs (ClubName VARCHAR(50))
IF @ClubName <> 'All'
  BEGIN
   EXEC procParseStringList @ClubName
   INSERT INTO #Clubs (ClubName) SELECT StringField FROM #tmpList
   TRUNCATE TABLE #tmpList
  END
  ELSE
  BEGIN
     INSERT INTO #Clubs VALUES('All') 
  END

/********  Foreign Currency Stuff ********/
DECLARE @ReportingCurrencyCode VARCHAR(15)
SET @ReportingCurrencyCode = 
(SELECT CASE WHEN COUNT(DISTINCT C.ValCurrencyCodeID) >=2 THEN 'USD' ELSE MAX(VCC.CurrencyCode) END AS ReportingCurrency
  FROM vClub C
  JOIN #Clubs ON C.ClubName = #Clubs.ClubName OR #Clubs.ClubName = 'All'
  JOIN vValCurrencyCode VCC ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID)

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

--Use vMMSCommissionableSalesSummary if the search period is within the scope of the table
IF @PostStartDate >= (SELECT MIN(PostDateTime) FROM dbo.vMMSCommissionableSalesSummary)
  BEGIN
SELECT CSS.ClubName, CSS.SalesPersonFirstName, CSS.SalesPersonLastName,CSS.SalesEmployeeID, 
       CSS.ReceiptNumber, CSS.MemberID,CSS.MemberFirstName FirstName, CSS.MemberLastName LastName, 
       CSS.CorporateCode,CSS.MembershipTypeDescription, CSS.ItemAmount * #PlanRate.PlanRate as ItemAmount, 
	   CSS.ItemAmount as LocalCurrency_ItemAmount, CSS.ItemAmount * #ToUSDPlanRate.PlanRate as USD_ItemAmount,
	   CSS.Quantity, CSS.CommissionCount as Count2, CSS.PostDateTime as PostDateTime_Sort, 
	   Replace(SubString(Convert(Varchar, CSS.PostDateTime),1,3)+' '+LTRIM(SubString(Convert(Varchar, CSS.PostDateTime),5,DataLength(Convert(Varchar, CSS.PostDateTime))-12)),' '+Convert(Varchar,Year(CSS.PostDateTime)),', '+Convert(Varchar,Year(CSS.PostDateTime))) + ' ' + LTRIM(SubString(Convert(Varchar, CSS.PostDateTime,22),10,5) + ' ' + Right(Convert(Varchar, CSS.PostDateTime ,22),2)) as PostDateTime,           
	   CSS.TranItemID,
       CSS.RegionDescription, CSS.DeptDescription, CSS.ProductDescription, 
       MS.CreatedDateTime AS MembershipCreatedDate, CSS.ProductID,CSS.AdvisorID,CSS.AdvisorFirstName,
       CSS.AdvisorLastName,
     CASE
       WHEN MS.CreatedDateTime Is Null
        THEN CSS.SalesEmployeeID
       WHEN DATEDIFF(d,MS.CreatedDateTime,CSS.PostDateTime)<=3
            AND CSS.ProductID = 88
       THEN CSS.AdvisorID
       ELSE CSS.SalesEmployeeID
       END CommReportEmployeeID,       
	   CSS.ItemDiscountAmount * #PlanRate.PlanRate as ItemDiscountAmount, 
	   CSS.ItemDiscountAmount as LocalCurrency_ItemDiscountAmount, 
	   CSS.ItemDiscountAmount * #ToUSDPlanRate.PlanRate as USD_ItemDiscountAmount,
/******  Foreign Currency Stuff  *********/
	   VCC.CurrencyCode as LocalCurrencyCode,
       #PlanRate.PlanRate,
       @ReportingCurrencyCode as ReportingCurrencyCode	     	
/***************************************/
  FROM dbo.vMMSCommissionableSalesSummary CSS
  JOIN vClub C									----- Added 4/15/09  SRM
       ON C.ClubID = CSS.ClubID
  JOIN #Depts DS 
       ON (CSS.DeptDescription = DS.DeptName OR DS.DeptName = 'All')
  JOIN #Clubs CS
       ON (C.ClubName = CS.ClubName OR CS.ClubName = 'All') ---- join to vClub 
/********** Foreign Currency Stuff **********/
  JOIN vValCurrencyCode VCC
       ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID
  JOIN #PlanRate
       ON VCC.CurrencyCode = #PlanRate.FromCurrencyCode
      AND YEAR(CSS.PostDateTime) = #PlanRate.PlanYear
  JOIN #ToUSDPlanRate
       ON VCC.CurrencyCode = #ToUSDPlanRate.FromCurrencyCode
      AND YEAR(CSS.PostDateTime) = #ToUSDPlanRate.PlanYear
/*******************************************/
  JOIN vMember M
       ON M.MemberID = CSS.MemberID
  JOIN vMembership MS
       ON MS.MembershipID = M.MembershipID

 WHERE CSS.PostDateTime >= @PostStartDate AND
       CSS.PostDateTime < @PostEndDate
END
ELSE
  BEGIN
--Find transactions that fall outside of the table

--Populate temporary table with Automated Refunds

SELECT 
       CASE MMST.ReasonCodeID
            WHEN 108
                 THEN MembershipClub.ClubID
                 ELSE OriginalTranClub.ClubID
       END AS ClubID,
       CASE MMST.ReasonCodeID
            WHEN 108
                 THEN MembershipClub.ClubName
                 ELSE OriginalTranClub.ClubName
       END AS ClubName,
       MIN(SC.SaleCommissionID) AS PrimarySalesPersonSalesCommissionID,
       MMST.ReceiptNumber, 
       OriginalM.MemberID, 
       OriginalM.FirstName AS MemberFirstName, 
       OriginalM.LastName AS MemberLastName, 
       CO.CorporateCode, 
       MS.MembershipTypeID,
       MSP.Description AS MembershipTypeDescription, 
       TI.ItemAmount,	   
       TI.Quantity, 
       1 AS CommissionCount,
       MMST.PostDateTime,
       MMST.UTCPostDateTime,
       TI.TranItemID,
       CASE MMST.ReasonCodeID
            WHEN 108
                 THEN MembershipClub.ValRegionID
                 ELSE OriginalTranClub.ValRegionID
       END AS ValRegionID,
       CASE MMST.ReasonCodeID
            WHEN 108
                 THEN MembershipRegion.Description 
                 ELSE OriginalRegion.Description 
       END AS RegionDescription,
       D.DepartmentID,
       D.Description AS DeptDescription,
       P.ProductID,
       P.Description AS ProductDescription,
       MS.CreatedDateTime AS MembershipCreatedDate,
       MembershipAdvisor.EmployeeID AS AdvisorID, 
       MembershipAdvisor.FirstName AS AdvisorFirstName, 
       MembershipAdvisor.LastName AS AdvisorLastName,       
	   TI.ItemDiscountAmount

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
	  JOIN #Clubs CS
		   ON (CASE MMST.ReasonCodeID
                    WHEN 108
                         THEN MembershipClub.ClubName
                    ELSE OriginalTranClub.ClubName
               END = CS.ClubName OR CS.ClubName = 'All')
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
	  JOIN #Depts DS 
		   ON (D.Description = DS.DeptName OR DS.DeptName = 'All')
 WHERE MMST.PostDateTime >= @PostStartDate 
   AND MMST.PostDateTime < @PostEndDate
   AND MMST.TranVoidedID IS NULL
   AND MMST.ValTranTypeID = 5

 GROUP BY 
       CASE MMST.ReasonCodeID
            WHEN 108
                 THEN MembershipClub.ClubID
                 ELSE OriginalTranClub.ClubID
       END,
       CASE MMST.ReasonCodeID
            WHEN 108
                 THEN MembershipClub.ClubName
                 ELSE OriginalTranClub.ClubName
       END,
       MMST.ReceiptNumber, 
       OriginalM.MemberID, 
       OriginalM.FirstName, 
       OriginalM.LastName, 
       CO.CorporateCode, 
       MS.MembershipTypeID,
       MSP.Description,
	   ItemAmount,
       LocalCurrency_ItemAmount,
	   USD_ItemAmount,
       TI.Quantity, 
       MMST.PostDateTime, 	   
       MMST.UTCPostDateTime,
       TI.TranItemID,
       CASE MMST.ReasonCodeID
            WHEN 108
                 THEN MembershipClub.ValRegionID
                 ELSE OriginalTranClub.ValRegionID
       END,
       CASE MMST.ReasonCodeID
            WHEN 108
                 THEN MembershipRegion.Description 
                 ELSE OriginalRegion.Description 
       END,
       D.DepartmentID,
       D.Description,
       P.ProductID,
       P.Description,
       MS.CreatedDateTime,
       MembershipAdvisor.EmployeeID, 
       MembershipAdvisor.FirstName, 
       MembershipAdvisor.LastName,
       ItemDiscountAmount, 
	   LocalCurrency_ItemDiscountAmount, 
	   USD_ItemDiscountAmount

--Find transactions that fall outside of the table (non-Automated Refunds)
SELECT C.ClubName, E.FirstName SalesPersonFirstName, E.LastName SalesPersonLastName,E.EmployeeID SalesEmployeeID, 
       MMST.ReceiptNumber, M.MemberID,M.FirstName, M.LastName, MMST.PostDateTime as PostDateTime_Sort,
	   Replace(SubString(Convert(Varchar, MMST.PostDateTime),1,3)+' '+LTRIM(SubString(Convert(Varchar, MMST.PostDateTime),5,DataLength(Convert(Varchar, MMST.PostDateTime))-12)),' '+Convert(Varchar,Year(MMST.PostDateTime)),', '+Convert(Varchar,Year(MMST.PostDateTime))) + ' ' + LTRIM(SubString(Convert(Varchar, MMST.PostDateTime,22),10,5) + ' ' + Right(Convert(Varchar, MMST.PostDateTime ,22),2)) as PostDateTime,           
       C2.CorporateCode, P.Description MembershipTypeDescription, TI.ItemAmount * #PlanRate.PlanRate as ItemAmount, 
	   TI.ItemAmount as LocalCurrency_ItemAmount, TI.ItemAmount * #ToUSDPlanRate.PlanRate as USD_ItemAmount, 
	   TI.Quantity, CSC.CommissionCount Count2, MMST.PostDateTime, TI.TranItemID,
       VR.Description RegionDescription, D.Description DeptDescription, P2.Description ProductDescription, 
       MS.CreatedDateTime AS MembershipCreatedDate, P2.ProductID, E2.EmployeeID AdvisorID,E2.FirstName AdvisorFirstName,
       E2.LastName AdvisorLastName,
     CASE
       WHEN MS.CreatedDateTime Is Null
        THEN E.EmployeeID
       WHEN DATEDIFF(d,MS.CreatedDateTime,MMST.PostDateTime)<=3
            AND TI.ProductID = 88
       THEN E2.EmployeeID
       ELSE E.EmployeeID
       END CommReportEmployeeID,
       TI.ItemDiscountAmount * #PlanRate.PlanRate as ItemDiscountAmount, 
	   TI.ItemDiscountAmount as LocalCurrency_ItemDiscountAmount, 
	   TI.ItemDiscountAmount * #ToUSDPlanRate.PlanRate as USD_ItemDiscountAmount,
/******  Foreign Currency Stuff  *********/
	   VCC.CurrencyCode as LocalCurrencyCode,
       #PlanRate.PlanRate,
       @ReportingCurrencyCode as ReportingCurrencyCode  	   	
/***************************************/
  FROM dbo.vMember M
	  JOIN dbo.vMMSTran MMST
	       ON M.MemberID = MMST.MemberID
	  JOIN dbo.vMembership MS
	       ON MS.MembershipID = MMST.MembershipID
	  JOIN dbo.vClub C
	       ON MMST.ClubID = C.ClubID
	  JOIN #Clubs CS
		   ON (C.ClubName = CS.ClubName OR CS.ClubName = 'All')
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
	  JOIN dbo.vValRegion VR
	       ON C.ValRegionID = VR.ValRegionID
	  JOIN dbo.vTranItem TI
	       ON MMST.MMSTranID = TI.MMSTranID
	  JOIN dbo.vProduct P2
	       ON TI.ProductID = P2.ProductID
	  JOIN dbo.vSaleCommission SC
	       ON TI.TranItemID = SC.TranItemID
	  JOIN dbo.vEmployee E
	       ON SC.EmployeeID = E.EmployeeID
	  JOIN dbo.vMembershipType MST
	       ON MS.MembershipTypeID = MST.MembershipTypeID
	  JOIN dbo.vProduct P
	       ON MST.ProductID = P.ProductID
	  JOIN dbo.vCommissionSplitCalc CSC
	       ON TI.TranItemID = CSC.TranItemID
	  JOIN dbo.vDepartment D
	       ON P2.DepartmentID = D.DepartmentID
	  JOIN #Depts DS 
		   ON (D.Description = DS.DeptName OR DS.DeptName = 'All')
	  LEFT JOIN dbo.vCompany C2
	       ON C2.CompanyID = MS.CompanyID
      LEFT JOIN dbo.vEmployee E2
		   ON MS.AdvisorEmployeeID = E2.EmployeeID
	 WHERE MMST.PostDateTime >= @PostStartDate 
		   AND MMST.PostDateTime < @PostEndDate
		   AND MMST.TranVoidedID IS NULL

UNION ALL
--Find transactions that fall outside of the table (Automated Refunds)
SELECT ARD.ClubName,
       E.FirstName AS SalesPersonFirstName,
       E.LastName AS SalesPersonLastName,
       E.EmployeeID AS SalesEmployeeID,
       ARD.ReceiptNumber,
       ARD.MemberID,
	   ARD.PostDateTime as PostDateTime_Sort,
	   Replace(SubString(Convert(Varchar, ARD.PostDateTime),1,3)+' '+LTRIM(SubString(Convert(Varchar, ARD.PostDateTime),5,DataLength(Convert(Varchar, ARD.PostDateTime))-12)),' '+Convert(Varchar,Year(ARD.PostDateTime)),', '+Convert(Varchar,Year(ARD.PostDateTime))) + ' ' + LTRIM(SubString(Convert(Varchar, ARD.PostDateTime,22),10,5) + ' ' + Right(Convert(Varchar, ARD.PostDateTime ,22),2)) as PostDateTime,           
       ARD.MemberFirstName,
       ARD.MemberLastName,
       ARD.CorporateCode,
       ARD.MembershipTypeDescription,
       ARD.ItemAmount * #PlanRate.PlanRate as ItemAmount,
	   ARD.ItemAmount as LocalCurrency_ItemAmount,
	   ARD.ItemAmount * #ToUSDPlanRate.PlanRate as USD_ItemAmount,
       ARD.Quantity,
       ARD.CommissionCount,	   
       ARD.TranItemID,
       ARD.RegionDescription,
       ARD.DeptDescription,
       ARD.ProductDescription,
       ARD.MembershipCreatedDate,
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
	   ARD.ItemDiscountAmount * #PlanRate.PlanRate as ItemDiscountAmount,
	   ARD.ItemDiscountAmount as LocalCurrency_ItemDiscountAmount,
	   ARD.ItemDiscountAmount * #ToUSDPlanRate.PlanRate as USD_ItemDiscountAmount,
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

DROP TABLE #Depts
DROP TABLE #Clubs
DROP TABLE #tmpList
DROP TABLE #PlanRate
DROP TABLE #ToUSDPlanRate

-- Report Logging
UPDATE HyperionReportLog
SET EndDateTime = getdate()
WHERE ReportLogID = @Identity

END

