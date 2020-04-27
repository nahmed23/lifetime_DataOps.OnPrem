--===========================================================================   

-- EXEC mmsRevenuerpt_Revenue 'Mar 1, 2011', 'Mar 15, 2011', '141', 'Personal Training', 'All'


CREATE PROC [dbo].[mmsRevenuerpt_Revenue] (
  @StartPostDate SMALLDATETIME,
  @EndPostDate SMALLDATETIME,
  @ClubList VARCHAR(8000),
  @DepartmentList VARCHAR(8000),
  @ProductIDList VARCHAR(1000)
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- =============================================
-- Object:			dbo.mmsRevenuerpt_Revenue
-- Author:			
-- Create date: 	
-- Description:		Returns a set of tran records for the Revenuerpt;
--					This proc adds 1 minute to the endpostdate to 
--					include records within the last minute;  it expects a 'PM'
--					to be included with the time portion, i.e., 11:59 PM;
-- 
-- Parameters:		Date range and three | separated lists one Clubs, Departments, ProductIDs-- Modified date:	
-- Modified Date:	3/3/08 GRB: inverted @StartDate and @EndDate when values are set
--                  07/16/2010 MLL: Added Discount information
--                  01/18/2011 BSD: Updated for businessrule to use TranItem.ClubID for MMSTran.ClubID = 9999
-- 
-- EXEC dbo.mmsRevenuerpt_Revenue '2/1/08', '2/29/08 11:59 PM', 'All', 'Merchandise', 'All'
-- EXEC dbo.mmsRevenuerpt_Revenue '2/1/08', '2/29/08 11:59 PM', 'All', 'Merchandise|Personal Training|Nutrition Coaching|Mind Body', 'All'
-- EXEC dbo.mmsRevenuerpt_Revenue '3/1/08', '4/29/08 11:59 PM', 'Lakeville, MN', 'Tennis', 'All'
-- EXEC dbo.mmsRevenuerpt_Revenue 'Apr 1, 2011', 'May 19, 2011 11:59 PM', 'Chanhassen, MN', 'Birthday Parties', 'All'
-- =============================================


  DECLARE @AdjustedEndPostDate AS SMALLDATETIME
  DECLARE @StartDate AS DATETIME
  DECLARE @EndDate AS DATETIME

--	inverted values assigned to @StartDate and @EndDate to comply with conditional logic below, determining which data source to use;
  SET @StartDate = DATEADD(m,-4,CONVERT(DATETIME,CONVERT(VARCHAR(11),GETDATE()))) --Four Months Old 
  SET @EndDate = CONVERT(DATETIME,CONVERT(VARCHAR(11),GETDATE())) --Today (the first moment, ie: 3/4/08 00:00:00 )


  SET @AdjustedEndPostDate = DATEADD(mi, 1, @EndPostDate)

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

  CREATE TABLE #tmpList (StringField VARCHAR(50))
  CREATE TABLE #Clubs (ClubName VARCHAR(50))
  IF @ClubList <> 'All'
    BEGIN
      EXEC procParseStringList @ClubList
      INSERT INTO #Clubs (ClubName) SELECT StringField FROM #tmpList
      TRUNCATE TABLE #tmpList
    END
  ELSE
    BEGIN
      INSERT INTO #Clubs (ClubName) SELECT ClubName FROM dbo.vClub
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
WHERE ToCurrencyCode = @ReportingCurrencyCode

CREATE TABLE #ToUSDPlanRate (PlanRate DECIMAL(14,4), FromCurrencyCode VARCHAR(15), PlanYear INT)
INSERT INTO #ToUSDPlanRate
SELECT PlanExchangeRate, FromCurrencyCode, PlanYear
FROM PlanExchangeRate
WHERE ToCurrencyCode = 'USD'
/***************************************/

  CREATE TABLE #Departments (Department VARCHAR(50))
  IF @DepartmentList <> 'All'
    BEGIN  
      EXEC procParseStringList @DepartmentList
      INSERT INTO #Departments (Department) SELECT StringField FROM #tmpList
      TRUNCATE TABLE #tmpList
    END
  ELSE
    BEGIN
      INSERT INTO #Departments (Department) SELECT Description FROM dbo.vDepartment
    END

  CREATE TABLE #Products (Product INT)
   IF @ProductIDList <> 'All'
     BEGIN
       EXEC procParseIntegerList @ProductIDList
       INSERT INTO #Products(Product)SELECT StringField FROM #tmpList
       TRUNCATE TABLE #tmpList
     END
    ELSE
     BEGIN
      INSERT INTO #Products VALUES(0)
     END
--	Use vMMSRevenueReportSummary if date range within the last four (4) months;
  IF @StartPostDate >= @StartDate AND
     @EndPostDate <= @EndDate		-- The summary table is only re-built once each night, so any query involving “today’s” data will need to use the MMSTran table
  BEGIN
          SELECT 
--				'MMSRevenueReportSummary' AS DataSource, @StartPostDate AS StartPostDate, 
--				@EndPostDate AS EndPostDate, @AdjustedEndPostDate AS AdjustedEndPostDate, 
--				@StartDate AS StartDate, @EndDate AS EndDate, 
				 PostingClubName, ItemAmount * #PlanRate.PlanRate as ItemAmount, 
				 ItemAmount as LocalCurrency_ItemAmount, ItemAmount * #ToUSDPlanRate.PlanRate as USD_ItemAmount,
				 DeptDescription, ProductDescription, MembershipClubname,
                 PostingClubid, DrawerActivityID, PostDateTime, TranDate as TranDate_Sort, 
				 Replace(SubString(Convert(Varchar, TranDate),1,3)+' '+LTRIM(SubString(Convert(Varchar, TranDate),5,DataLength(Convert(Varchar, TranDate))-12)),' '+Convert(Varchar,Year(TranDate)),', '+Convert(Varchar,Year(TranDate))) + ' ' + LTRIM(SubString(Convert(Varchar, TranDate,22),10,5) + ' ' + Right(Convert(Varchar, TranDate ,22),2)) as TranDate,    
				 TranTypeDescription, ValTranTypeID,
                 MemberID, ItemSalesTax * #PlanRate.PlanRate as ItemSalesTax, ItemSalesTax as LocalCurrency_ItemSalesTax, 
			     ItemSalesTax * #ToUSDPlanRate.PlanRate as USD_ItemSalesTax, EmployeeID, PostingRegionDescription, MemberFirstname, MemberLastname,
                 EmployeeFirstname, EmployeeLastname, ReasonCodeDescription, TranItemID, TranMemberJoinDate,
                 MMSR.MembershipID, ProductID, TranClubid, Quantity, @StartPostDate AS ReportStartDate,
                 @EndPostDate AS ReportEndDate, CO.CompanyName, CO.CorporateCode, VMS.Description as MembershipSourceDescription,
                 ItemDiscountAmount * #PlanRate.PlanRate as ItemDiscountAmount,
				 ItemDiscountAmount as LocalCurrency_ItemDiscountAmount,
				 ItemDiscountAmount * #ToUSDPlanRate.PlanRate as USD_ItemDiscountAmount,
                 DiscountAmount1 * #PlanRate.PlanRate as DiscountAmount1,
				 DiscountAmount1 as LocalCurrency_DiscountAmount1,
				 DiscountAmount1 * #ToUSDPlanRate.PlanRate as USD_DiscountAmount1,				 
                 DiscountAmount2 * #PlanRate.PlanRate as DiscountAmount2,
				 DiscountAmount2 as LocalCurrency_DiscountAmount2,
	             DiscountAmount2 * #ToUSDPlanRate.PlanRate as USD_DiscountAmount2,
                 DiscountAmount3 * #PlanRate.PlanRate as DiscountAmount3,
				 DiscountAmount3 as LocalCurrency_DiscountAmount2,
				 DiscountAmount3 * #ToUSDPlanRate.PlanRate as USD_DiscountAmount3,
                 DiscountAmount4 * #PlanRate.PlanRate as DiscountAmount4,
				 DiscountAmount4 as LocalCurrency_DiscountAmount2,
				 DiscountAmount4 * #ToUSDPlanRate.PlanRate as USD_DiscountAmount4,
                 DiscountAmount5 * #PlanRate.PlanRate as DiscountAmount5,
				 DiscountAmount5 as LocalCurrency_DiscountAmount2,
				 DiscountAmount5 * #ToUSDPlanRate.PlanRate as USD_DiscountAmount5,
                 Discount1,
                 Discount2,
                 Discount3,
                 Discount4,
                 Discount5,
/******  Foreign Currency Stuff  *********/
	   VCC.CurrencyCode as LocalCurrencyCode,
       #PlanRate.PlanRate,
       @ReportingCurrencyCode as ReportingCurrencyCode	   	
/***************************************/
 
          FROM vMMSRevenueReportSummary MMSR
               JOIN #Clubs CS
                 ON MMSR.PostingClubName = CS.ClubName
				/********** Foreign Currency Stuff **********/
			      JOIN vClub C
				       ON CS.ClubName = C.ClubName
				  JOIN vValCurrencyCode VCC
					   ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID
				  JOIN #PlanRate
					   ON VCC.CurrencyCode = #PlanRate.FromCurrencyCode
					  AND YEAR(MMSR.PostDateTime) = #PlanRate.PlanYear
				  JOIN #ToUSDPlanRate
					   ON VCC.CurrencyCode = #ToUSDPlanRate.FromCurrencyCode
					  AND YEAR(MMSR.PostDateTime) = #ToUSDPlanRate.PlanYear
				/*******************************************/
               JOIN #Departments DS
                 ON MMSR.DeptDescription = DS.Department
               JOIN #Products PS
                 ON (MMSR.ProductID = PS.Product OR PS.Product = 0)
 	           JOIN dbo.vMembership MS 
		         ON MS.MembershipID = MMSR.MembershipID
 	           LEFT JOIN dbo.vCompany CO 
                 ON MS.CompanyID = CO.CompanyID
			   LEFT JOIN vValMembershipSource VMS
				 ON MS.ValMembershipSourceID = VMS.ValMembershipSourceID
          WHERE MMSR.PostDateTime >= @StartPostDate AND
                MMSR.PostDateTime < @AdjustedEndPostdate 
  END
  ELSE

---- If the requested date range falls outside of the summary table data

  BEGIN

-- returns data on all unvoided automated refund transactions , 
-- posted in the selected period 

CREATE TABLE #RefundTranIDs (
       MMSTranRefundID INT,
       RefundMMSTranID INT,
       RefundReasonCodeID INT,
       MembershipClubID INT,
       MembershipClubName NVARCHAR(50),
       MembershipRegionID INT,
       MembershipGLClubID INT,
       MembershipGLTaxID INT,
       MembershipRegionDescription	NVARCHAR(50))

INSERT INTO #RefundTranIDs
SELECT MMSTR.MMSTranRefundID,
       MMST.MMSTranID,
       MMST.ReasonCodeID,
       MS.ClubID,
       C.ClubName,
       R.ValRegionID,
       C.GLClubID,
       C.GLTaxID,
       R.Description
  FROM vMMSTranRefund  MMSTR
  JOIN vMMSTran  MMST
    ON MMST.MMSTranID = MMSTR.MMSTranID
  JOIN vMembership MS
    ON MS.MembershipID = MMST.MembershipID
  JOIN vClub C
    ON C.ClubID = MS.ClubID
  JOIN vValRegion R
    ON R.ValRegionID = C.ValRegionID
  JOIN vTranItem TI
    ON MMST.MMSTranID = TI.MMSTranID
  JOIN vProduct P
    ON P.ProductID = TI.ProductID
  JOIN vDepartment D
    ON P.DepartmentID = D.DepartmentID
  JOIN #Products PS
    ON P.ProductID = PS.Product 
    OR PS.Product = 0
  JOIN #Departments DS
    ON D.Description = DS.Department
 WHERE MMST.TranVoidedID IS NULL
   AND MMST.PostDateTime >= @StartPostDate
   AND MMST.PostDateTime < @AdjustedEndPostDate

-- This query returns original MMSTran transaction data and current membership club
-- data gathered in #RefundTranIDs
-- to determine the club where transaction will be assigned


CREATE TABLE #ReportRefunds (
       RefundMMSTranID INT,
       PostingGLTaxID INT,
       PostingGLClubID INT,
       PostingRegionDescription NVARCHAR(50),
       PostingClubName NVARCHAR(50),
       PostingMMSClubID INT)

INSERT INTO #ReportRefunds
SELECT RTID.RefundMMSTranID,
       CASE 
            WHEN TranClub.ClubID = 9999 THEN CASE WHEN TI.ClubID IS NULL THEN TranClub.GLTaxID ELSE TranItemClub.GLTaxID END   --1/31/2011 BSD
            WHEN RTID.RefundReasonCodeID = 108 OR TranClub.ClubID = 13
                 THEN RTID.MembershipGLTaxID
            ELSE TranClub.GLTaxID
       END,
       CASE
            WHEN TranClub.ClubID = 9999 THEN CASE WHEN TI.ClubID IS NULL THEN TranClub.GLClubID ELSE TranItemClub.GLClubID END   --1/31/2011 BSD
            WHEN RTID.RefundReasonCodeID = 108 OR TranClub.ClubID = 13
                 THEN RTID.MembershipGLClubID
            ELSE TranClub.GLClubID
       END,
       CASE
            WHEN TranClub.ClubID = 9999 THEN CASE WHEN TI.ClubID IS NULL THEN TranRegion.Description ELSE TranItemRegion.Description END   --1/31/2011 BSD
            WHEN RTID.RefundReasonCodeID = 108 OR TranClub.ClubID = 13
                 THEN RTID.MembershipRegionDescription
            ELSE TranRegion.Description
       END,
       CASE
            WHEN TranClub.ClubID = 9999 THEN CASE WHEN TI.ClubID IS NULL THEN TranClub.ClubName ELSE TranItemClub.ClubName END   --1/31/2011 BSD
            WHEN RTID.RefundReasonCodeID = 108 OR TranClub.ClubID = 13
                 THEN RTID.MembershipClubName
            ELSE TranClub.ClubName
       END,
       CASE
            WHEN TranClub.ClubID = 9999 THEN CASE WHEN TI.ClubID IS NULL THEN TranClub.ClubID ELSE TranItemClub.ClubID END   --1/31/2011 BSD
            WHEN RTID.RefundReasonCodeID = 108 OR TranClub.ClubID = 13
                 THEN RTID.MembershipClubID
            ELSE TranClub.ClubID
       END
  FROM #RefundTranIDs  RTID
  JOIN vMMSTranRefundMMSTran  MMSTRT
    ON MMSTRT.MMSTranRefundID = RTID.MMSTranRefundID
  JOIN vMMSTran  MMST
    ON MMST.MMSTranID = MMSTRT.OriginalMMSTranID
  JOIN vClub TranClub
    ON TranClub.ClubID = MMST.ClubID
  JOIN vValRegion  TranRegion
    ON TranRegion.ValRegionID = TranClub.ValRegionID
  LEFT JOIN vTranItem TI   --1/31/2011 BSD
    ON MMST.MMSTranID = TI.MMSTranID   --1/31/2011 BSD
  LEFT JOIN vClub TranItemClub   --1/31/2011 BSD
    ON TI.ClubID = TranItemClub.ClubID   --1/31/2011 BSD
  LEFT JOIN vValRegion TranItemRegion   --1/31/2011 BSD
    ON TranItemClub.ValRegionID = TranItemRegion.ValRegionID   --1/31/2011 BSD
GROUP BY RTID.RefundMMSTranID,
       CASE 
            WHEN TranClub.ClubID = 9999 THEN CASE WHEN TI.ClubID IS NULL THEN TranClub.GLTaxID ELSE TranItemClub.GLTaxID END   --1/31/2011 BSD
            WHEN RTID.RefundReasonCodeID = 108 OR TranClub.ClubID = 13
                 THEN RTID.MembershipGLTaxID
            ELSE TranClub.GLTaxID
       END,
       CASE
            WHEN TranClub.ClubID = 9999 THEN CASE WHEN TI.ClubID IS NULL THEN TranClub.GLClubID ELSE TranItemClub.GLClubID END   --1/31/2011 BSD
            WHEN RTID.RefundReasonCodeID = 108 OR TranClub.ClubID = 13
                 THEN RTID.MembershipGLClubID
            ELSE TranClub.GLClubID
       END,
       CASE
            WHEN TranClub.ClubID = 9999 THEN CASE WHEN TI.ClubID IS NULL THEN TranRegion.Description ELSE TranItemRegion.Description END   --1/31/2011 BSD
            WHEN RTID.RefundReasonCodeID = 108 OR TranClub.ClubID = 13
                 THEN RTID.MembershipRegionDescription
            ELSE TranRegion.Description
       END,
       CASE
            WHEN TranClub.ClubID = 9999 THEN CASE WHEN TI.ClubID IS NULL THEN TranClub.ClubName ELSE TranItemClub.ClubName END   --1/31/2011 BSD
            WHEN RTID.RefundReasonCodeID = 108 OR TranClub.ClubID = 13
                 THEN RTID.MembershipClubName
            ELSE TranClub.ClubName
       END,
       CASE
            WHEN TranClub.ClubID = 9999 THEN CASE WHEN TI.ClubID IS NULL THEN TranClub.ClubID ELSE TranItemClub.ClubID END   --1/31/2011 BSD
            WHEN RTID.RefundReasonCodeID = 108 OR TranClub.ClubID = 13
                 THEN RTID.MembershipClubID
            ELSE TranClub.ClubID
       END


--- This query gathers discount data for all tranitem records in the period 
--- which have discount data

CREATE TABLE #TMPDiscount (
       TranItemID INT,
       ItemAmount MONEY,
       TotalDiscountAmount MONEY,
       ReceiptText1 VARCHAR(50),
       AppliedDiscountAmount1 MONEY,
       ReceiptText2 VARCHAR(50),
       AppliedDiscountAmount2 MONEY,
       ReceiptText3 VARCHAR(50),
       AppliedDiscountAmount3 MONEY,
       ReceiptText4 VARCHAR(50),
       AppliedDiscountAmount4 MONEY,
       ReceiptText5 VARCHAR(50),
       AppliedDiscountAmount5 MONEY)

DECLARE @TranItemID INT,
        @ItemAmount MONEY,
        @TotalDiscountAmount MONEY,
        @ReceiptText VARCHAR(50),
        @AppliedDiscountAmount MONEY,
        @HOLDTranItemID INT,
        @Counter INT

SET @HOLDTranItemID = -1
SET @Counter = 1

DECLARE Discount_Cursor CURSOR LOCAL READ_ONLY FOR
SELECT TI.TranItemID, TI.ItemAmount, TI.ItemDiscountAmount as TotalDiscountAmount,SP.ReceiptText,TID.AppliedDiscountAmount
  FROM vMMSTran MMST
  JOIN vTranItem TI
    ON MMST.MMSTranID = TI.MMSTranID
  JOIN vValTranType VTT
    ON VTT.ValTranTypeID = MMST.ValTranTypeID
  JOIN vTranItemDiscount TID
    ON TID.TranItemID = TI.TranItemID
  JOIN vPricingDiscount PD
    ON PD.PricingDiscountID = TID.PricingDiscountID
  JOIN vSalesPromotion SP
    ON PD.SalesPromotionID = SP.SalesPromotionID
  JOIN vProduct P
    ON TI.ProductID = P.ProductID
  JOIN vDepartment D
    ON P.DepartmentID = D.DepartmentID
  JOIN #Products PS
    ON P.ProductID = PS.Product
    OR PS.Product = 0
  JOIN #Departments DS
    ON D.Description = DS.Department

 WHERE MMST.PostDateTime >= @StartPostDate
   AND MMST.PostDateTime < @AdjustedEndPostDate
   AND MMST.TranVoidedID IS NULL
   AND D.Description IN ('Merchandise', 'Personal Training', 'Nutrition Coaching', 'Mind Body','Mixed Combat Arts')
 ORDER BY TI.TranItemID, PD.SalesPromotionID

OPEN Discount_Cursor
FETCH NEXT FROM Discount_Cursor INTO @TranItemID,@ItemAmount,@TotalDiscountAmount,@ReceiptText,@AppliedDiscountAmount
WHILE (@@FETCH_STATUS = 0)
    BEGIN

        IF @TranItemID != @HOLDTranItemID
            BEGIN
                INSERT INTO #TMPDiscount
                   (TranItemID, ItemAmount, TotalDiscountAmount, ReceiptText1, AppliedDiscountAmount1)
                VALUES (@TranItemID,@ItemAmount,@TotalDiscountAmount,@ReceiptText,@AppliedDiscountAmount)
                SET @HOLDTranItemID = @TranItemID
                SET @Counter = 1
            END
        ELSE
            BEGIN
                SET @Counter = @Counter + 1
                IF @Counter = 2
                    BEGIN
                        UPDATE #TMPDiscount SET ReceiptText2 = @ReceiptText, AppliedDiscountAmount2 = @AppliedDiscountAmount
                         WHERE TranItemID = @TranItemID
                    END
                IF @Counter = 3
                    BEGIN
                        UPDATE #TMPDiscount SET ReceiptText3 = @ReceiptText, AppliedDiscountAmount3 = @AppliedDiscountAmount
                          WHERE TranItemID = @TranItemID
                    END
                IF @Counter = 4
                    BEGIN
                        UPDATE #TMPDiscount SET ReceiptText4 = @ReceiptText, AppliedDiscountAmount4 = @AppliedDiscountAmount
                          WHERE TranItemID = @TranItemID
                    END
                IF @Counter = 5
                    BEGIN
                        UPDATE #TMPDiscount SET ReceiptText5 = @ReceiptText, AppliedDiscountAmount5 = @AppliedDiscountAmount
                         WHERE TranItemID = @TranItemID
                    END
                SET @HOLDTranItemID = @TranItemID
            END

    FETCH NEXT FROM Discount_Cursor INTO @TranItemID,@ItemAmount,@TotalDiscountAmount,@ReceiptText,@AppliedDiscountAmount
    END

CLOSE Discount_Cursor
DEALLOCATE Discount_Cursor 

          SELECT 
--				'MMSTran' AS DataSource, @StartPostDate AS StartPostDate, @EndPostDate AS EndPostDate, 
--				@AdjustedEndPostDate AS AdjustedEndPostDate, @StartDate AS StartDate, @EndDate AS EndDate, 
				
--C.ClubName AS PostingClubName,  -- 1/18/2011 BSD
CASE WHEN C.ClubID = 9999 THEN CASE WHEN TI.ClubID is NULL THEN C.ClubName ELSE TranItemClub.ClubName END ELSE C.ClubName END AS PostingClubName,
                 TI.ItemAmount * #PlanRate.PlanRate as ItemAmount, TI.ItemAmount as LocalCurrency_ItemAmount,
				 TI.ItemAmount * #ToUSDPlanRate.PlanRate as USD_ItemAmount, D.Description DeptDescription,
                 P.Description ProductDescription, C2.ClubName AS MembershipClubname, 
--C.ClubID AS PostingClubid, -- 1/18/2011 BSD
CASE WHEN C.ClubID = 9999 THEN CASE WHEN TI.ClubID is NULL THEN C.ClubID ELSE TranItemClub.ClubID END ELSE C.ClubID END AS PostingClubid,
                 MMST.DrawerActivityID, MMST.PostDateTime, MMST.TranDate as TranDate_Sort,
				 Replace(SubString(Convert(Varchar, MMST.TranDate),1,3)+' '+LTRIM(SubString(Convert(Varchar, MMST.TranDate),5,DataLength(Convert(Varchar, MMST.TranDate))-12)),' '+Convert(Varchar,Year(MMST.TranDate)),', '+Convert(Varchar,Year(MMST.TranDate))) + ' ' + LTRIM(SubString(Convert(Varchar, MMST.TranDate,22),10,5) + ' ' + Right(Convert(Varchar, MMST.TranDate ,22),2)) as TranDate,    
                 VTT.Description TranTypeDescription, MMST.ValTranTypeID, MMST.MemberID,
                 TI.ItemSalesTax * #PlanRate.PlanRate as ItemSalesTax, TI.ItemSalesTax as LocalCurrency_ItemSalesTax, 
			     TI.ItemSalesTax * #ToUSDPlanRate.PlanRate as USD_ItemSalesTax, MMST.EmployeeID, 
--CVR.Description AS PostingRegionDescription, -- 1/18/2011 BSD
CASE WHEN C.ClubID = 9999 THEN CASE WHEN TI.ClubID is NULL THEN CVR.Description ELSE TranItemRegion.Description END ELSE CVR.Description END AS PostingRegionDescription,
                 M.FirstName MemberFirstname, M.LastName MemberLastname, E.FirstName EmployeeFirstname,
                 E.LastName EmployeeLastname, RC.Description ReasonCodeDescription, TI.TranItemID,
                 M.JoinDate TranMemberJoinDate, MMST.MembershipID, P.ProductID, 
--MMST.ClubID TranClubid, -- 1/18/2011 BSD
CASE WHEN C.ClubID = 9999 THEN CASE WHEN TI.ClubID is NULL THEN C.ClubID ELSE TranItemClub.ClubID END ELSE C.ClubID END AS TranClubid,
                 TI.Quantity,
                 @StartPostDate AS ReportStartDate,@EndPostDate AS ReportEndDate, CO.CompanyName, CO.CorporateCode,
				 VMS.Description as MembershipSourceDescription,
                 TI.ItemDiscountAmount * #PlanRate.PlanRate as ItemDiscountAmount,
				 TI.ItemDiscountAmount as LocalCurrency_ItemDiscountAmount,
				 TI.ItemDiscountAmount * #ToUSDPlanRate.PlanRate as USD_ItemDiscountAmount,
                 #TMP.AppliedDiscountAmount1 * #PlanRate.PlanRate as DiscountAmount1,
				 #TMP.AppliedDiscountAmount1 as LocalCurrency_DiscountAmount1,
				 #TMP.AppliedDiscountAmount1 * #ToUSDPlanRate.PlanRate as USD_DiscountAmount1,
                 #TMP.AppliedDiscountAmount2 * #PlanRate.PlanRate as DiscountAmount2,
				 #TMP.AppliedDiscountAmount2 as LocalCurrency_DiscountAmount2,
				 #TMP.AppliedDiscountAmount2 * #ToUSDPlanRate.PlanRate as USD_DiscountAmount2,
                 #TMP.AppliedDiscountAmount3 * #PlanRate.PlanRate as DiscountAmount3,
				 #TMP.AppliedDiscountAmount3 as LocalCurrency_DiscountAmount3,
				 #TMP.AppliedDiscountAmount3 * #ToUSDPlanRate.PlanRate as USD_DiscountAmount3,
                 #TMP.AppliedDiscountAmount4  * #PlanRate.PlanRate as DiscountAmount4,
				 #TMP.AppliedDiscountAmount4 as LocalCurrency_DiscountAmount4,
				 #TMP.AppliedDiscountAmount4 * #ToUSDPlanRate.PlanRate as USD_DiscountAmount4,
                 #TMP.AppliedDiscountAmount5 * #PlanRate.PlanRate as DiscountAmount5,
				 #TMP.AppliedDiscountAmount5 as LocalCurrency_DiscountAmount5,	
				 #TMP.AppliedDiscountAmount5 * #ToUSDPlanRate.PlanRate as USD_DiscountAmount5,
                 #TMP.ReceiptText1 as Discount1,
                 #TMP.ReceiptText2 as Discount2,
                 #TMP.ReceiptText3 as Discount3,
                 #TMP.ReceiptText4 as Discount4,
                 #TMP.ReceiptText5 as Discount5,
/******  Foreign Currency Stuff  *********/
	   VCC.CurrencyCode as LocalCurrencyCode,
       #PlanRate.PlanRate,
       @ReportingCurrencyCode as ReportingCurrencyCode	
/***************************************/

          FROM dbo.vMMSTran MMST 
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
               JOIN #Clubs CI
                 ON C.ClubName = CI.ClubName
               JOIN dbo.vValRegion CVR
                 ON C.ValRegionID = CVR.ValRegionID
               JOIN dbo.vTranItem TI
                 ON TI.MMSTranID = MMST.MMSTranID
               LEFT JOIN dbo.vClub TranItemClub -- 1/18/2011 BSD
                 ON TI.ClubID = TranItemClub.ClubID -- 1/18/2011 BSD
               LEFT JOIN dbo.vValRegion TranItemRegion -- 1/18/2011 BSD
                 ON TranItemRegion.ValRegionID = TranItemClub.ValRegionID -- 1/18/2011 BSD
               JOIN dbo.vProduct P
                 ON P.ProductID = TI.ProductID
               JOIN #Products PS
                 ON (P.ProductID = PS.Product OR PS.Product = 0)
               JOIN dbo.vDepartment D
                 ON D.DepartmentID = P.DepartmentID
               JOIN #Departments DS
                 ON D.Description = DS.Department
               JOIN dbo.vMembership MS
                 ON MS.MembershipID = MMST.MembershipID
               JOIN dbo.vClub C2
                 ON MS.ClubID = C2.ClubID
               JOIN dbo.vValTranType VTT
                 ON MMST.ValTranTypeID = VTT.ValTranTypeID
               JOIN dbo.vMember M
                 ON M.MemberID = MMST.MemberID
               JOIN dbo.vReasonCode RC
                 ON RC.ReasonCodeID = MMST.ReasonCodeID
               LEFT JOIN dbo.vMMSTranRefund MTR 
                 ON MMST.MMSTranID = MTR.MMSTranID
               LEFT OUTER JOIN dbo.vEmployee E 
                 ON MMST.EmployeeID = E.EmployeeID
  	           LEFT JOIN dbo.vCompany CO 
                 ON MS.CompanyID = CO.CompanyID
			   LEFT JOIN vValMembershipSource VMS
				 ON MS.ValMembershipSourceID = VMS.ValMembershipSourceID
               LEFT JOIN #TMPDiscount #TMP  
                 ON TI.TranItemID = #TMP.TranItemID

         WHERE MMST.PostDateTime >= @StartPostDate 
               AND MMST.PostDateTime < @AdjustedEndPostdate 
               AND MMST.TranVoidedID IS NULL 
               AND VTT.ValTranTypeID IN (1, 3, 4, 5) 
               AND C.ClubID not in(13)     
               AND MTR.MMSTranRefundID IS NULL


  UNION ALL

	  SELECT 
--			'MMSTran' AS DataSource, @StartPostDate AS StartPostDate, @EndPostDate AS EndPostDate, 
--			@AdjustedEndPostDate AS AdjustedEndPostDate, @StartDate AS StartDate, @EndDate AS EndDate, 
			C2.ClubName AS PostingClubName, 
             TI.ItemAmount * #PlanRate.PlanRate as ItemAmount, TI.ItemAmount as LocalCurrency_ItemAmount,
			 TI.ItemAmount * #ToUSDPlanRate.PlanRate as USD_ItemAmount, D.Description DeptDescription,
	         P.Description ProductDescription, C2.ClubName MembershipClubname, 
            C2.ClubID AS PostingClubid, 
             MMST.DrawerActivityID,
	         MMST.PostDateTime, MMST.TranDate as TranDate_Sort,
			 Replace(SubString(Convert(Varchar, MMST.TranDate),1,3)+' '+LTRIM(SubString(Convert(Varchar, MMST.TranDate),5,DataLength(Convert(Varchar, MMST.TranDate))-12)),' '+Convert(Varchar,Year(MMST.TranDate)),', '+Convert(Varchar,Year(MMST.TranDate))) + ' ' + LTRIM(SubString(Convert(Varchar, MMST.TranDate,22),10,5) + ' ' + Right(Convert(Varchar, MMST.TranDate ,22),2)) as TranDate,    
		     VTT.Description TranTypeDescription,
	         MMST.ValTranTypeID, M.MemberID, TI.ItemSalesTax * #PlanRate.PlanRate as ItemSalesTax, TI.ItemSalesTax as LocalCurrency_ItemSalesTax, 
			 TI.ItemSalesTax * #ToUSDPlanRate.PlanRate as USD_ItemSalesTax, MMST.EmployeeID,
             C2VR.Description AS PostingRegionDescription,
	         M.FirstName MemberFirstname, M.LastName MemberLastname,
	         E.FirstName EmployeeFirstname, E.LastName EmployeeLastname, RC.Description ReasonCodeDescription,
	         TI.TranItemID, M.JoinDate TranMemberJoinDate, MMST.MembershipID,
	         P.ProductID, MMST.ClubID TranClubid, TI.Quantity,@StartPostDate AS ReportStartDate,@EndPostDate AS ReportEndDate, CO.CompanyName, CO.CorporateCode,
			 VMS.Description as MembershipSourceDescription,
                 TI.ItemDiscountAmount * #PlanRate.PlanRate as ItemDiscountAmount,
				 TI.ItemDiscountAmount as LocalCurrency_ItemDiscountAmount,
				 TI.ItemDiscountAmount * #ToUSDPlanRate.PlanRate as USD_ItemDiscountAmount,
                 #TMP.AppliedDiscountAmount1 * #PlanRate.PlanRate as DiscountAmount1,
				 #TMP.AppliedDiscountAmount1 as LocalCurrency_DiscountAmount1,
				 #TMP.AppliedDiscountAmount1 * #ToUSDPlanRate.PlanRate as USD_DiscountAmount1,
                 #TMP.AppliedDiscountAmount2 * #PlanRate.PlanRate as DiscountAmount2,
				 #TMP.AppliedDiscountAmount2 as LocalCurrency_DiscountAmount2,
				 #TMP.AppliedDiscountAmount2 * #ToUSDPlanRate.PlanRate as USD_DiscountAmount2,
                 #TMP.AppliedDiscountAmount3 * #PlanRate.PlanRate as DiscountAmount3,
				 #TMP.AppliedDiscountAmount3 as LocalCurrency_DiscountAmount3,
				 #TMP.AppliedDiscountAmount3 * #ToUSDPlanRate.PlanRate as USD_DiscountAmount3,
                 #TMP.AppliedDiscountAmount4  * #PlanRate.PlanRate as DiscountAmount4,
				 #TMP.AppliedDiscountAmount4 as LocalCurrency_DiscountAmount4,
				 #TMP.AppliedDiscountAmount4 * #ToUSDPlanRate.PlanRate as USD_DiscountAmount4,
                 #TMP.AppliedDiscountAmount5 * #PlanRate.PlanRate as DiscountAmount5,
				 #TMP.AppliedDiscountAmount5 as LocalCurrency_DiscountAmount5,	
				 #TMP.AppliedDiscountAmount5 * #ToUSDPlanRate.PlanRate as USD_DiscountAmount5,
                 #TMP.ReceiptText1 as Discount1,
                 #TMP.ReceiptText2 as Discount2,
                 #TMP.ReceiptText3 as Discount3,
                 #TMP.ReceiptText4 as Discount4,
                 #TMP.ReceiptText5 as Discount5,
/******  Foreign Currency Stuff  *********/
	   VCC.CurrencyCode as LocalCurrencyCode,
       #PlanRate.PlanRate,
       @ReportingCurrencyCode as ReportingCurrencyCode   	
/***************************************/
	  FROM dbo.vMMSTran MMST
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
           --JOIN dbo.vValRegion CVR
	         --ON C.ValRegionID = CVR.ValRegionID
	       JOIN dbo.vTranItem TI
	         ON TI.MMSTranID = MMST.MMSTranID
	       JOIN dbo.vProduct P
	         ON P.ProductID = TI.ProductID
           JOIN #Products PS
             ON (P.ProductID = PS.Product OR PS.Product = 0)
	       JOIN dbo.vDepartment D
             ON D.DepartmentID = P.DepartmentID
	       JOIN dbo.vMembership MS
	         ON MS.MembershipID = MMST.MembershipID
	       JOIN dbo.vClub C2
	         ON MS.ClubID = C2.ClubID
           JOIN #Clubs 
              ON C2.ClubName = #Clubs.ClubName

	       JOIN dbo.vValRegion C2VR
	         ON C2.ValRegionID = C2VR.ValRegionID
	       JOIN dbo.vValTranType VTT
	         ON MMST.ValTranTypeID = VTT.ValTranTypeID
	       JOIN dbo.vMember M
	         ON M.MemberID = MMST.MemberID
	       JOIN dbo.vReasonCode RC
	         ON RC.ReasonCodeID = MMST.ReasonCodeID
           LEFT JOIN dbo.vMMSTranRefund MTR 
             ON MMST.MMSTranID = MTR.MMSTranID 
	       LEFT OUTER JOIN dbo.vEmployee E
	         ON MMST.EmployeeID = E.EmployeeID
 	       LEFT JOIN dbo.vCompany CO 
             ON MS.CompanyID = CO.CompanyID
		   LEFT JOIN vValMembershipSource VMS
			 ON MS.ValMembershipSourceID = VMS.ValMembershipSourceID
           LEFT JOIN #TMPDiscount #TMP
             ON TI.TranItemID = #TMP.TranItemID
	  WHERE MMST.PostDateTime >= @StartPostDate
			AND MMST.PostDateTime < @AdjustedEndPostDate
			AND MMST.TranVoidedID IS NULL
			AND VTT.ValTranTypeID IN (1,3,4,5)
			AND C.ClubID in(13)    -- 1/18/2011 BSD
			AND D.Description IN (Select Department from #Departments)
			AND MTR.MMSTranRefundID IS NULL

UNION ALL

---- Automated Refunds 

SELECT #RR.PostingClubName,
       TI.ItemAmount * #PlanRate.PlanRate as ItemAmount, TI.ItemAmount as LocalCurrency_ItemAmount,
	   TI.ItemAmount * #ToUSDPlanRate.PlanRate as USD_ItemAmount,
       D.Description as DeptDescription,
       P.Description as ProductDescription,
       C2.ClubName as MembershipClubname,
       #RR.PostingMMSClubID as PostingClubID,
       MMST.DrawerActivityID,
       MMST.PostDateTime,
       MMST.TranDate as TranDate_Sort,
	   Replace(SubString(Convert(Varchar, MMST.TranDate),1,3)+' '+LTRIM(SubString(Convert(Varchar, MMST.TranDate),5,DataLength(Convert(Varchar, MMST.TranDate))-12)),' '+Convert(Varchar,Year(MMST.TranDate)),', '+Convert(Varchar,Year(MMST.TranDate))) + ' ' + LTRIM(SubString(Convert(Varchar, MMST.TranDate,22),10,5) + ' ' + Right(Convert(Varchar, MMST.TranDate ,22),2)) as TranDate,    
       VTT.Description as TranTypeDescription,
       MMST.ValTranTypeID,
       MMST.MemberID,
       TI.ItemSalesTax * #PlanRate.PlanRate as ItemSalesTax, TI.ItemSalesTax as LocalCurrency_ItemSalesTax, 
	   TI.ItemSalesTax * #ToUSDPlanRate.PlanRate as USD_ItemSalesTax,
       MMST.EmployeeID,
       #RR.PostingRegionDescription as PostingRegionDescription,
       M.FirstName as MemberFirstname,
       M.LastName as MemberLastname,
       E.FirstName as EmployeeFirstname,
       E.LastName as EmployeeLastname,
       RC.Description as ReasonCodeDescription,
       TI.TranItemID,
       M.JoinDate as TranMemberJoinDate,
       MMST.MembershipID,
       P.ProductID,
       MMST.ClubID as TranClubid,
       TI.Quantity,
       @StartPostDate as ReportStartDate,
       @EndPostDate as ReportEndDate,
       CO.CompanyName,
       CO.CorporateCode,
       VMS.Description as MembershipSourceDescription,
	   TI.ItemDiscountAmount * #PlanRate.PlanRate as ItemDiscountAmount,
	   TI.ItemDiscountAmount as LocalCurrency_ItemDiscountAmount,
	   TI.ItemDiscountAmount * #ToUSDPlanRate.PlanRate as USD_ItemDiscountAmount,
	   #TMP.AppliedDiscountAmount1 * #PlanRate.PlanRate as DiscountAmount1,
	   #TMP.AppliedDiscountAmount1 as LocalCurrency_DiscountAmount1,
	   #TMP.AppliedDiscountAmount1 * #ToUSDPlanRate.PlanRate as USD_DiscountAmount1,
	   #TMP.AppliedDiscountAmount2 * #PlanRate.PlanRate as DiscountAmount2,
	   #TMP.AppliedDiscountAmount2 as LocalCurrency_DiscountAmount2,
	   #TMP.AppliedDiscountAmount2 * #ToUSDPlanRate.PlanRate as USD_DiscountAmount2,
	   #TMP.AppliedDiscountAmount3 * #PlanRate.PlanRate as DiscountAmount3,
	   #TMP.AppliedDiscountAmount3 as LocalCurrency_DiscountAmount3,
	   #TMP.AppliedDiscountAmount3 * #ToUSDPlanRate.PlanRate as USD_DiscountAmount3,
	   #TMP.AppliedDiscountAmount4  * #PlanRate.PlanRate as DiscountAmount4,
	   #TMP.AppliedDiscountAmount4 as LocalCurrency_DiscountAmount4,
	   #TMP.AppliedDiscountAmount4 * #ToUSDPlanRate.PlanRate as USD_DiscountAmount4,
	   #TMP.AppliedDiscountAmount5 * #PlanRate.PlanRate as DiscountAmount5,
	   #TMP.AppliedDiscountAmount5 as LocalCurrency_DiscountAmount5,	
	   #TMP.AppliedDiscountAmount5 * #ToUSDPlanRate.PlanRate as USD_DiscountAmount5,
       #TMP.ReceiptText1 as Discount1,
       #TMP.ReceiptText2 as Discount2,
       #TMP.ReceiptText3 as Discount3,
       #TMP.ReceiptText4 as Discount4,
       #TMP.ReceiptText5 as Discount5,
/******  Foreign Currency Stuff  *********/
	   VCC.CurrencyCode as LocalCurrencyCode,
       #PlanRate.PlanRate,
       @ReportingCurrencyCode as ReportingCurrencyCode	   	
/***************************************/

  FROM vMMSTran MMST
  JOIN #ReportRefunds #RR
    ON #RR.RefundMMSTranID = MMST.MMSTranID
  JOIN #Clubs #CS 
    ON #RR.PostingClubName = #CS.ClubName
  JOIN vTranItem  TI
    ON TI.MMSTranID = MMST.MMSTranID
  JOIN vProduct P
    ON P.ProductID = TI.ProductID
  JOIN vDepartment D
    ON D.DepartmentID = P.DepartmentID
  JOIN vMembership MS
    ON MS.MembershipID = MMST.MembershipID
  JOIN vClub  C2
    ON MS.ClubID = C2.ClubID
/********** Foreign Currency Stuff **********/
  JOIN vClub C3
       ON #RR.PostingMMSClubID = C3.ClubID
  JOIN vValCurrencyCode VCC
       ON C3.ValCurrencyCodeID = VCC.ValCurrencyCodeID
  JOIN #PlanRate
       ON VCC.CurrencyCode = #PlanRate.FromCurrencyCode
      AND YEAR(MMST.PostDateTime) = #PlanRate.PlanYear
  JOIN #ToUSDPlanRate
       ON VCC.CurrencyCode = #ToUSDPlanRate.FromCurrencyCode
      AND YEAR(MMST.PostDateTime) = #ToUSDPlanRate.PlanYear
/*******************************************/
  JOIN vValTranType VTT
    ON MMST.ValTranTypeID = VTT.ValTranTypeID
  JOIN vMember M
    ON M.MemberID = MMST.MemberID
  JOIN vReasonCode  RC
    ON RC.reasonCodeID = MMST.ReasonCodeID
  LEFT JOIN vEmployee E
    ON MMST.EmployeeID = E.EmployeeID  
  LEFT JOIN vCompany CO
    ON MS.CompanyID = CO.CompanyID    
  LEFT JOIN vValMembershipSource VMS
    ON MS.ValMembershipSourceID = VMS.ValMembershipSourceID    
  LEFT JOIN #TMPDiscount #TMP
    ON TI.TranItemID = #TMP.TranItemID

DROP TABLE #RefundTranIDs
DROP TABLE #ReportRefunds
DROP TABLE #TMPDiscount

  END

  DROP TABLE #Clubs
  DROP TABLE #Departments
  DROP TABLE #Products
  DROP TABLE #tmpList
  DROP TABLE #PlanRate
  DROP TABLE #ToUSDPlanRate

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END

