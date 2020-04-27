


-- =============================================
-- Object:			dbo.mmsSalesSummary_Revenue
-- Author:			
-- Create date: 	
-- Description:		Returns a recordset specific to the SalesSummary Brio Document for
--					the qRevenue Query section
-- Modified date:	3/9/2011 BSD: Updated to add new business rule below to Group By - was causing errors
--                  1/18/2011 BSD: Updated for new ClubID = 9999 business rule to use TranItem.ClubID
--                  10/19/2010 BSD: Updated filter to act the same with ClubID=9999 as ClubID=13
--					10/31/2008 GRB: added quantity calculation to account for negative
--					values before summing them; deploying 11/5/2008 dbcr_3771
-- Parameters:		Date range for the MMS POS transaction and 
--					a | separated list of Clubs and 
--					another | separated list of Departments
--
-- EXEC dbo.mmsSalesSummary_Revenue 'Apr 1, 2011', 'Apr 3, 2011', '141', '14|16|3|5|13|8|1|11|2|7|10|19|9|17|6|18|4|12|15'
-- =============================================

CREATE   PROC [dbo].[mmsSalesSummary_Revenue] (
  @StartDate SMALLDATETIME,
  @EndDate SMALLDATETIME,
  @ClubIDList VARCHAR(2000),
  @DepartmentIDList VARCHAR(1000)
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON
  DECLARE @SummaryStartDate AS DATETIME
  DECLARE @SummaryEndDate AS DATETIME

  SET @SummaryStartDate = CONVERT(DATETIME,CONVERT(VARCHAR,DATEADD(m,-1, GETDATE() - DAY(GETDATE()-1)),110),110)
  SET @SummaryEndDate = CONVERT(DATETIME,CONVERT(VARCHAR,GETDATE(),110),110)

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

  CREATE TABLE #tmpList (StringField VARCHAR(50))
  
  EXEC procParseStringList @ClubIDList
  CREATE TABLE #Clubs (ClubID VARCHAR(50))
  INSERT INTO #Clubs (ClubID) SELECT StringField FROM #tmpList
  TRUNCATE TABLE #tmpList

  EXEC procParseStringList @DepartmentIDList
  CREATE TABLE #Departments (DepartmentID VARCHAR(50))
  INSERT INTO #Departments (DepartmentID) SELECT StringField FROM #tmpList

/********  Foreign Currency Stuff ********/
DECLARE @ReportingCurrencyCode VARCHAR(15)
SET @ReportingCurrencyCode = 
(SELECT CASE WHEN COUNT(DISTINCT C.ValCurrencyCodeID) >=2 THEN 'USD' ELSE MAX(VCC.CurrencyCode) END AS ReportingCurrency
  FROM vClub C
  JOIN #Clubs ON C.ClubID = #Clubs.ClubID
  JOIN vValCurrencyCode VCC ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID)

CREATE TABLE #PlanRate (PlanRate DECIMAL(14,4), FromCurrencyCode VARCHAR(15), PlanYear INT)
INSERT INTO #PlanRate
SELECT PlanExchangeRate, FromCurrencyCode, PlanYear
FROM PlanExchangeRate
WHERE ToCurrencyCode = @ReportingCurrencyCode

CREATE TABLE #ToUSDPlanRate (PlanRate DECIMAL(14,4), FromCurrencyCode VARCHAR(15), PlanYear INT)
INSERT INTO #ToUSDPlanRate
SELECT PlanExchangeRate, FromCurrencyCode, PlanYear
FROM PlanExchangeRate
WHERE ToCurrencyCode = 'USD'
/***************************************/

  IF @StartDate >= @SummaryStartDate
     AND @EndDate < @SummaryEndDate
  BEGIN
         SELECT PostingRegionDescription, PostingClubname, 
                SUM ( ItemAmount * #PlanRate.PlanRate ) as ItemAmount, 
				SUM ( ItemAmount ) as LocalCurrency_ItemAmount,
				SUM ( ItemAmount * #ToUSDPlanRate.PlanRate) as USD_ItemAmount, MMSR.DepartmentID,
                DeptDescription, ProductDescription, MembershipClubname, 
                PostingClubID, DrawerActivityID, TranTypeDescription, 
                ValTranTypeID, 
				SUM ( ItemSalesTax * #PlanRate.PlanRate) ItemSalesTax,
				SUM ( ItemSalesTax ) as LocalCurrency_ItemSalesTax,
				SUM ( ItemSalesTax * #ToUSDPlanRate.PlanRate) USD_ItemSalesTax,
				EmployeeID, 
                EmployeeFirstname, EmployeeLastname, TranClubid, 
                ProductID, 
--				SUM ( Quantity ) Quantity		10/31/2008 GRB: deprecated this line and added the follwing four lines of code
				SUM (	CASE WHEN ItemAmount < 0 THEN -(Quantity)
							ELSE Quantity
						END
					 ) Quantity,
	   VCC.CurrencyCode as LocalCurrencyCode,
       #PlanRate.PlanRate,
       @ReportingCurrencyCode as ReportingCurrencyCode
--				,CONVERT(DATETIME,CONVERT(VARCHAR,MMSR.PostDateTime,110),110) MMSPostDate
         FROM vMMSRevenueReportSummary MMSR
              JOIN #Clubs CS
                ON MMSR.PostingClubID = CS.ClubID
--                ON MMSR.PostingClubName = CS.ClubName
              JOIN #Departments DS
                ON MMSR.DepartmentID = DS.DepartmentID
/********** Foreign Currency Stuff **********/
  JOIN vClub C
	   ON CS.ClubID = C.ClubID
  JOIN vValCurrencyCode VCC
       ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID
  JOIN #PlanRate
       ON VCC.CurrencyCode = #PlanRate.FromCurrencyCode
      AND YEAR(MMSR.PostDateTime) = #PlanRate.PlanYear
  JOIN #ToUSDPlanRate
       ON VCC.CurrencyCode = #ToUSDPlanRate.FromCurrencyCode
      AND YEAR(MMSR.PostDateTime) = #ToUSDPlanRate.PlanYear
/*******************************************/
--                ON MMSR.DeptDescription = DS.Department
         WHERE MMSR.TranTypeDescription IN ('Adjustment', 'Charge', 'Sale') AND 
               MMSR.PostDateTime >=  @StartDate AND 
               MMSR.PostDateTime < @EndDate  
         GROUP BY PostingRegionDescription, MembershipClubname, 
		  MMSR.DepartmentID, DeptDescription, 
                  ProductDescription, PostingClubname, PostingClubID, 
                  DrawerActivityID, TranTypeDescription, ValTranTypeID, 
                  EmployeeID, EmployeeFirstname, EmployeeLastname, 
                  ProductID, TranClubid,---, MMSR.PostDateTime
				  VCC.CurrencyCode, #PlanRate.PlanRate
  END	
  ELSE
  BEGIN
         SELECT --VR.Description PostingRegionDescription, 
                CASE WHEN C1.ClubID = 9999 THEN CASE WHEN TI.ClubID is NULL THEN VR.Description ELSE TranItemRegion.Description END ELSE VR.Description END AS PostingRegionDescription, --3/9/2011 BSD                  
                --C1.ClubName PostingClubName, 
                CASE WHEN C1.ClubID = 9999 THEN CASE WHEN TI.ClubID is NULL THEN C1.ClubName ELSE TranItemClub.ClubName END ELSE C1.ClubName END AS PostingClubName, --3/9/2011 BSD  
				SUM ( TI.ItemAmount * #PlanRate.PlanRate ) as ItemAmount, 
				SUM ( TI.ItemAmount ) as LocalCurrency_ItemAmount,
				SUM ( TI.ItemAmount * #ToUSDPlanRate.PlanRate) as USD_ItemAmount,                
				D.DepartmentID,
                D.Description DeptDescription, P.Description ProductDescription, C2.ClubName MembershipClubname, 
                MMST.ClubID PostingClubID, MMST.DrawerActivityID, VTT.Description TranTypeDescription, 
                MMST.ValTranTypeID, 
				SUM ( TI.ItemSalesTax * #PlanRate.PlanRate) ItemSalesTax,
				SUM ( TI.ItemSalesTax ) as LocalCurrency_ItemSalesTax,
				SUM ( TI.ItemSalesTax * #ToUSDPlanRate.PlanRate) USD_ItemSalesTax,
				MMST.EmployeeID, 
                E.FirstName EmployeeFirstname, E.LastName EmployeeLastname, 
                --C1.ClubID TranClubid, 
                CASE WHEN C1.ClubID = 9999 THEN CASE WHEN TI.ClubID is NULL THEN C1.ClubID ELSE TranItemClub.ClubID END ELSE C1.ClubID END AS TranClubID, --3/9/2011 BSD                           
                P.ProductID, 
--				SUM ( TI.Quantity ) Quantity		10/31/2008 GRB: deprecated this line and added the follwing four lines of code
				SUM (	CASE WHEN ItemAmount < 0 THEN -(TI.Quantity)
							ELSE TI.Quantity
						END
					 ) Quantity,
	   VCC.CurrencyCode as LocalCurrencyCode,
       #PlanRate.PlanRate,
       @ReportingCurrencyCode as ReportingCurrencyCode
--				, CONVERT(DATETIME,CONVERT(VARCHAR,MMST.PostDateTime,110),110) MMSPostDate
         FROM dbo.vMMSTran MMST
              JOIN dbo.vClub C1
                ON C1.ClubID = MMST.ClubID
              JOIN #Clubs CS
                ON C1.ClubID = CS.ClubID
/********** Foreign Currency Stuff **********/
  JOIN vValCurrencyCode VCC
       ON C1.ValCurrencyCodeID = VCC.ValCurrencyCodeID
  JOIN #PlanRate
       ON VCC.CurrencyCode = #PlanRate.FromCurrencyCode
      AND YEAR(MMST.PostDateTime) = #PlanRate.PlanYear
  JOIN #ToUSDPlanRate
       ON VCC.CurrencyCode = #ToUSDPlanRate.FromCurrencyCode
      AND YEAR(MMST.PostDateTime) = #ToUSDPlanRate.PlanYear
/*******************************************/
--                ON C1.ClubName = CS.ClubName
              JOIN dbo.vValRegion VR
                ON C1.ValRegionID = VR.ValRegionID
              JOIN dbo.vTranItem TI
                ON TI.MMSTranID = MMST.MMSTranID
              LEFT JOIN vClub TranItemClub --1/18/2011 BSD
                ON TI.ClubID = TranItemClub.ClubID --1/18/2011 BSD
              LEFT JOIN vValRegion TranItemRegion --1/18/2011 BSD
                ON TranItemClub.ValRegionID = TranItemRegion.ValRegionID --1/18/2011 BSD
              JOIN dbo.vProduct P
                ON P.ProductID = TI.ProductID
              JOIN dbo.vDepartment D
                ON D.DepartmentID = P.DepartmentID
              JOIN #Departments DS
                ON D.DepartmentID = DS.DepartmentID
--                ON D.Description = DS.Department
              JOIN dbo.vMembership MS
                ON MS.MembershipID = MMST.MembershipID
              JOIN dbo.vClub C2
                ON MS.ClubID = C2.ClubID
              JOIN dbo.vValTranType VTT
                ON MMST.ValTranTypeID = VTT.ValTranTypeID
              LEFT OUTER JOIN dbo.vEmployee E 
                ON E.EmployeeID = MMST.EmployeeID
         WHERE VTT.Description IN ('Adjustment', 'Charge', 'Sale') AND 
               MMST.TranVoidedID IS NULL AND 
               C2.ClubID not in(13) AND--10/19/2010 BSD  --1/18/2011 BSD
               MMST.PostDateTime >=  @StartDate AND 
               MMST.PostDateTime < @EndDate --AND 
         GROUP BY CASE WHEN C1.ClubID = 9999 THEN CASE WHEN TI.ClubID is NULL THEN VR.Description ELSE TranItemRegion.Description END ELSE VR.Description END,
                  CASE WHEN C1.ClubID = 9999 THEN CASE WHEN TI.ClubID is NULL THEN C1.ClubName ELSE TranItemClub.ClubName END ELSE C1.ClubName END,
                  D.DepartmentID, D.Description, 
                  P.Description, C2.ClubName, MMST.ClubID, 
                  MMST.DrawerActivityID, VTT.Description, MMST.ValTranTypeID, 
                  MMST.EmployeeID, E.FirstName, E.LastName, 
                  CASE WHEN C1.ClubID = 9999 THEN CASE WHEN TI.ClubID is NULL THEN C1.ClubID ELSE TranItemClub.ClubID END ELSE C1.ClubID END, --1/18/2011 BSD
                  P.ProductID,----, MMST.PostDateTime
				  VCC.CurrencyCode, #PlanRate.PlanRate
         
         UNION
  
         SELECT VR.Description PostingRegionDescription, C2.ClubName PostingClubname,                 
				SUM ( TI.ItemAmount * #PlanRate.PlanRate ) as ItemAmount, 
				SUM ( TI.ItemAmount ) as LocalCurrency_ItemAmount,
				SUM ( TI.ItemAmount * #ToUSDPlanRate.PlanRate) as USD_ItemAmount, 
				D.DepartmentID,
                D.Description DeptDescription, P.Description ProductDescription, C2.ClubName MembershipClubname, 
                C2.ClubID PostingClubid, MMST.DrawerActivityID, VTT.Description TranTypeDescription, 
                VTT.ValTranTypeID, 
				SUM ( TI.ItemSalesTax * #PlanRate.PlanRate) ItemSalesTax,
				SUM ( TI.ItemSalesTax ) as LocalCurrency_ItemSalesTax,
				SUM ( TI.ItemSalesTax * #ToUSDPlanRate.PlanRate) USD_ItemSalesTax, 
                E.EmployeeID, E.FirstName EmployeeFirstname, E.LastName EmployeeLastname, 
                P.ProductID, C1.ClubID TranClubid, 
--				SUM ( TI.Quantity ) Quantity	10/31/2008 GRB: deprecated this line and added the follwing four lines of code
				SUM (	CASE WHEN ItemAmount < 0 THEN -(Quantity)
							ELSE Quantity
						END
					 ) Quantity,
	   VCC.CurrencyCode as LocalCurrencyCode,
       #PlanRate.PlanRate,
       @ReportingCurrencyCode as ReportingCurrencyCode
--				, CONVERT(DATETIME,CONVERT(VARCHAR,MMST.PostDateTime,110),110) MMSPostDate
         FROM dbo.vClub C1
              JOIN dbo.vMMSTran MMST 
                ON C1.ClubID = MMST.ClubID
/********** Foreign Currency Stuff **********/
  JOIN vValCurrencyCode VCC
       ON C1.ValCurrencyCodeID = VCC.ValCurrencyCodeID
  JOIN #PlanRate
       ON VCC.CurrencyCode = #PlanRate.FromCurrencyCode
      AND YEAR(MMST.PostDateTime) = #PlanRate.PlanYear
  JOIN #ToUSDPlanRate
       ON VCC.CurrencyCode = #ToUSDPlanRate.FromCurrencyCode
      AND YEAR(MMST.PostDateTime) = #ToUSDPlanRate.PlanYear
/*******************************************/
              JOIN dbo.vTranItem TI
                ON TI.MMSTranID = MMST.MMSTranID
              JOIN dbo.vProduct P
                ON P.ProductID = TI.ProductID
              JOIN dbo.vDepartment D
                ON D.DepartmentID = P.DepartmentID
              JOIN #Departments DS
                ON D.DepartmentID = DS.DepartmentID
--                ON D.Description = DS.Department
              JOIN dbo.vMembership MS
                ON MS.MembershipID = MMST.MembershipID
              JOIN dbo.vClub C2
                ON MS.ClubID = C2.ClubID
              JOIN #Clubs CS
                ON C2.ClubID = CS.ClubID
--                ON C2.ClubName = CS.ClubName
              JOIN dbo.vValRegion VR
                ON C2.ValRegionID = VR.ValRegionID
              JOIN dbo.vValTranType VTT
                ON MMST.ValTranTypeID = VTT.ValTranTypeID
              LEFT OUTER JOIN dbo.vEmployee E 
                ON E.EmployeeID = MMST.EmployeeID
         WHERE C1.ClubID in(13) AND --10/19/2010 BSD  --1/18/2011 BSD
               VTT.Description IN ('Adjustment', 'Charge', 'Sale') AND 
               MMST.TranVoidedID IS NULL AND 
               MMST.PostDateTime >= @StartDate AND 
               MMST.PostDateTime < @EndDate --AND 
         GROUP BY VR.Description, C2.ClubName, D.DepartmentID, D.Description, 
                  P.Description, C2.ClubName, C2.ClubID, 
                  MMST.DrawerActivityID, VTT.Description, VTT.ValTranTypeID, 
                  E.EmployeeID, E.FirstName, E.LastName, 
                  P.ProductID, C1.ClubID,-----, MMST.PostDateTime
				  VCC.CurrencyCode, #PlanRate.PlanRate
   END
   DROP TABLE #Clubs
   DROP TABLE #Departments
   DROP TABLE #tmpList

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END

