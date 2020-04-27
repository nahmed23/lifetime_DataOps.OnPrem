


-- =============================================
-- Object:			dbo.mmsRecurrentProductDetail
-- Author:			Greg Burdick
-- Create date: 	6/4/2008
-- Release date:	6/11/2008 dbcr_3274
-- Description:		
-- 
-- Parameters:		Date range and two | separated lists: Club(s), (Recurrent) Product(s); all values passed are ID (INT) value
-- Modified Date:	6/17/2009 GRB: removed incorrect 'SoldDate' alias from M.JoinDate column per QC#3338; 
--						also added 	M.ActiveFlag to second query to make columns consistent; deploying via dbcr_4682 on 6/24/09
-- 
-- EXEC dbo.mmsRecurrentProductDetail '5/1/09', '5/31/09 11:59 PM', '137|151|164|174', '1644|1185|1868|3056|3122|3123|3126'
-- EXEC dbo.mmsRecurrentProductDetail 'Mar 1, 2010', 'Apr 2, 2011', '151', '1644|1185|1868|3056|3122|3123|3126'
-- =============================================

CREATE PROC [dbo].[mmsRecurrentProductDetail_Obsolete] (
  @ParmStartDate DATETIME,
  @ParmEndDate DATETIME,
  @ClubIDList VARCHAR(2000),
  @RecurrentProductIDList VARCHAR(2000)
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

  DECLARE @AdjustedParmEndDate AS DATETIME
  DECLARE @CalcRecentStartDate AS DATETIME
  DECLARE @CalcRecentEndDate AS DATETIME

  SET @CalcRecentStartDate = DATEADD(m,-4,CONVERT(DATETIME,CONVERT(VARCHAR(11),GETDATE()))) --Four Months Old 
  SET @CalcRecentEndDate = CONVERT(DATETIME,CONVERT(VARCHAR(11),GETDATE())) --Today (the first moment, ie: 3/4/08 00:00:00 )

  SET @AdjustedParmEndDate = DATEADD(mi, 1, @ParmEndDate)

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

  CREATE TABLE #tmpList (StringField VARCHAR(50))

-- Parse the ClubIDs into a temp table
  CREATE TABLE #Clubs(ClubID INT)
    BEGIN
      EXEC procParseIntegerList @ClubIDList
      INSERT INTO #Clubs(ClubID) SELECT StringField FROM #tmpList
      TRUNCATE TABLE #tmpList
    END

  CREATE TABLE #Products (ProductID INT)
    BEGIN
      EXEC procParseIntegerList @RecurrentProductIDList
      INSERT INTO #Products(ProductID) SELECT StringField FROM #tmpList
      TRUNCATE TABLE #tmpList
    END

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
WHERE PlanYear >= Year(@ParmStartDate)
  AND PlanYear <= Year(@ParmEndDate)
  AND ToCurrencyCode = @ReportingCurrencyCode

CREATE TABLE #ToUSDPlanRate (PlanRate DECIMAL(14,4), FromCurrencyCode VARCHAR(15), PlanYear INT)
INSERT INTO #ToUSDPlanRate
SELECT PlanExchangeRate, FromCurrencyCode, PlanYear
FROM PlanExchangeRate
WHERE PlanYear >= Year(@ParmStartDate)
  AND PlanYear <= Year(@ParmEndDate)
  AND ToCurrencyCode = 'USD'
/***************************************/

--	Use vMMSRevenueReportSummary if date range within the last four (4) months;
IF @ParmStartDate >= @CalcRecentStartDate AND
	@AdjustedParmEndDate <= @CalcRecentEndDate		-- The summary table is only re-built once each night, so any query involving “today’s” data will need to use the MMSTran table
  BEGIN
	SELECT
--	'MMSRevenueReportSummary' AS DataSource, @ParmStartDate AS StartPostDate, 
--	@ParmEndDate AS EndPostDate, @AdjustedParmEndDate AS AdjustedParmEndDate, 
--	@ParmStartDate AS ParmStartDate, @ParmEndDate AS ParmEndDate, 
    VR.Description RegionDescription,
	C.ClubID, C.ClubName, 
	vrpt.ValRecurrentProductTypeID,
	vrpt.Description AS RecurrentProductType,
	P.Name ProductName, 
	P.Description AS RecurrentProductDescription,	 	
	MMSRRS.MembershipID,
	M.MemberID,
	M.FirstName, 
	M.LastName,
--	M.JoinDate SoldDate,		-- 6/17/2009 GRB
    M.JoinDate,
	MMSRRS.PostDateTime,
    P.DepartmentID,
	M.ActiveFlag,
/******  Foreign Currency Stuff  *********/
	   VCC.CurrencyCode as LocalCurrencyCode,
       #PlanRate.PlanRate,
       @ReportingCurrencyCode as ReportingCurrencyCode,
	   MMSRRS.ItemAmount * #PlanRate.PlanRate as ItemAmount,	   
	   MMSRRS.ItemAmount as LocalCurrency_ItemAmount,	   	  
	   MMSRRS.ItemAmount * #ToUSDPlanRate.PlanRate as USD_ItemAmount,
	   MMSRRS.ItemSalesTax * #PlanRate.PlanRate as ItemSalesTax,
	   MMSRRS.ItemSalesTax as LocalCurrency_ItemSalesTax,
	   MMSRRS.ItemSalesTax * #ToUSDPlanRate.PlanRate as USD_ItemSalesTax,
	  (MMSRRS.ItemAmount + MMSRRS.ItemSalesTax) * #PlanRate.PlanRate as Tranamount,
	   MMSRRS.ItemAmount + MMSRRS.ItemSalesTax as LocalCurrency_Tranamount,
	  (MMSRRS.ItemAmount + MMSRRS.ItemSalesTax) * #ToUSDPlanRate.PlanRate as USD_Tranamount	   
/***************************************/

	FROM vMMSRevenueReportSummary MMSRRS
		JOIN vProduct P ON MMSRRS.ProductID = P.ProductID
		JOIN #Products #P ON P.ProductID = #P.ProductID
		JOIN vMember M ON MMSRRS.MemberID = M.MemberID
		JOIN vDepartment D ON P.DepartmentID = D.DepartmentID
		JOIN vClub C ON MMSRRS.PostingClubID = C.ClubID
		JOIN #Clubs #C ON C.ClubID = #C.ClubID
		JOIN vValRegion VR ON C.ValRegionID = VR.ValRegionID
		JOIN vValRecurrentProductType vrpt ON P.ValRecurrentProductTypeID = vrpt.ValRecurrentProductTypeID
/********** Foreign Currency Stuff **********/
  JOIN vValCurrencyCode VCC
       ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID
  JOIN #PlanRate
       ON VCC.CurrencyCode = #PlanRate.FromCurrencyCode
      AND YEAR(MMSRRS.PostDateTime) = #PlanRate.PlanYear
  JOIN #ToUSDPlanRate
       ON VCC.CurrencyCode = #ToUSDPlanRate.FromCurrencyCode
      AND YEAR(MMSRRS.PostDateTime) = #ToUSDPlanRate.PlanYear
/*******************************************/

	WHERE MMSRRS.ValTranTypeID = 1 AND -- TranType 1 is a Charge Transaction
		MMSRRS.PostDateTime >= @ParmStartDate AND
		MMSRRS.PostDateTime <= @AdjustedParmEndDate AND
		C.DisplayUIFlag = 1		-- omits 'Corporate' clubs

	ORDER BY 
		VR.Description, 
		C.ClubName, 
		vrpt.Description,	-- RecurrentProductType,
		P.Description		-- RecurrentProductDescription,

  END
ELSE
  BEGIN
	SELECT
--		'vMMSTran' AS DataSource, @ParmStartDate AS ParmStartDate, 
--		@ParmEndDate AS ParmEndDate, @AdjustedParmEndDate AS AdjustedParmEndDate, 
--		@CalcRecentStartDate AS CalcRecentStartDate, @CalcRecentEndDate AS CalcRecentEndDate, 
		VR.Description RegionDescription,
		C.ClubID, C.ClubName, 
		vrpt.ValRecurrentProductTypeID,
		vrpt.Description AS RecurrentProductType,
		P.Name ProductName, 
		P.Description AS RecurrentProductDescription,		
		MMST.MembershipID,
		M.MemberID,
		M.FirstName, 
		M.LastName,
--		M.JoinDate SoldDate,		-- 6/17/2009 GRB
		M.JoinDate,
		MMST.PostDateTime,
		P.DepartmentID,
		M.ActiveFlag,				-- added 6/17/2009 GRB
/******  Foreign Currency Stuff  *********/
	   VCC.CurrencyCode as LocalCurrencyCode,
       #PlanRate.PlanRate,
       @ReportingCurrencyCode as ReportingCurrencyCode,
       TI.ItemAmount * #PlanRate.PlanRate as ItemAmount,
	   TI.ItemAmount as LocalCurrency_ItemAmount,
	   TI.ItemAmount * #ToUSDPlanRate.PlanRate as USD_ItemAmount,
	   TI.ItemSalesTax * #PlanRate.PlanRate as ItemSalesTax,
	   TI.ItemSalesTax as LocalCurrency_ItemSalesTax,
	   TI.ItemSalesTax * #ToUSDPlanRate.PlanRate as USD_ItemSalesTax,
	   MMST.TranAmount * #PlanRate.PlanRate as TranAmount,
	   MMST.TranAmount as LocalCurrency_TranAmount,	   
	   MMST.TranAmount * #ToUSDPlanRate.PlanRate as USD_TranAmount
/***************************************/

		FROM vMMSTran MMST
			JOIN vTranItem TI ON MMST.MMSTranID = TI.MMSTranID
			JOIN vProduct P ON TI.ProductID = P.ProductID
			JOIN #Products #P ON P.ProductID = #P.ProductID
			JOIN vMember M ON MMST.MemberID = M.MemberID
			JOIN vDepartment D ON P.DepartmentID = D.DepartmentID
			JOIN vClub C ON MMST.ClubID = C.ClubID
			JOIN #Clubs #C ON C.ClubID = #C.ClubID
			JOIN vValRegion VR ON C.ValRegionID = VR.ValRegionID
			JOIN vValRecurrentProductType vrpt ON P.ValRecurrentProductTypeID = vrpt.ValRecurrentProductTypeID
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
	
		WHERE MMST.ValTranTypeID = 1 AND -- TranType 1 is a Charge Transaction
			MMST.PostDateTime >= @ParmStartDate AND
			MMST.PostDateTime <= @AdjustedParmEndDate AND
			C.DisplayUIFlag = 1		-- omits 'Corporate' clubs

		ORDER BY 
			VR.Description, 
			C.ClubName, 
			vrpt.Description,	-- RecurrentProductType,
			P.Description		-- RecurrentProductDescription,
  END

  DROP TABLE #Clubs
  DROP TABLE #Products
  DROP TABLE #tmpList
  DROP TABLE #PlanRate
  DROP TABLE #ToUSDPlanRate

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END

