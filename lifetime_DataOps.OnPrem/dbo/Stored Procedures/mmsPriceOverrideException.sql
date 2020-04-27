




CREATE Procedure [dbo].[mmsPriceOverrideException](
    @ClubID VARCHAR(2000),
    @Department VARCHAR(200),
    @ReportStartDate SMALLDATETIME,
    @ReportEndDate SMALLDATETIME
)
AS
BEGIN
SET XACT_ABORT  ON
SET NOCOUNT ON

-- EXECUTE [mmsPriceOverrideException]  '132|136|176|8|151|20|21|22|30|35', '20|21|22|23|1|2|10|3|4|5|6|7|8|9|11|12|13|14|15|17|16|18|19', '10/01/2009', '10/31/2009'
-- EXECUTE mmsPriceOverrideException  '141', '8|9', 'Apr 1, 2011', 'Apr 3, 2011'
-- 07/08/2010 MLL Added Discount reporting per RR 422
-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY


-- clubs
CREATE TABLE #tmpList (StringField VARCHAR(15))
CREATE TABLE #Clubs (ClubID VARCHAR(15))
EXEC procParseStringList @ClubID
INSERT INTO #Clubs (ClubID) SELECT StringField FROM #tmpList
TRUNCATE TABLE #tmpList

/********  Foreign Currency Stuff ********/
DECLARE @ReportingCurrencyCode VARCHAR(15)
SET @ReportingCurrencyCode = 
(SELECT CASE WHEN COUNT(DISTINCT C.ValCurrencyCodeID) >=2 THEN 'USD' ELSE MAX(VCC.CurrencyCode) END AS ReportingCurrency
  FROM vClub C
  JOIN #Clubs ON C.ClubID = #Clubs.ClubID OR #Clubs.ClubID = 0
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

-- departments
CREATE TABLE #Departments (DepartmentID VARCHAR(15))
EXEC procParseStringList @Department
INSERT INTO #Departments (DepartmentID) SELECT StringField FROM #tmpList
TRUNCATE TABLE #tmpList 

-- select all transactions into temp table
CREATE TABLE #tMMSTran (
DrawerActivityID INT,
MMSTranID INT,
TranDate datetime,
ClubID INT,
MemberID INT,
EmployeeID INT)

INSERT INTO #tMMSTran
SELECT 
MMST.DrawerActivityID,
MMST.MMSTranID,
MMST.TranDate,
MMST.ClubID,
MMST.MemberID,
MMST.EmployeeID
FROM vMMSTran MMST 
JOIN #Clubs #C ON MMST.ClubID = #C.ClubID  
WHERE
MMST.ValTranTypeID = 3 -- sale transaction only
AND MMST.TranVoidedID is null -- not voided
AND MMST.TranEditedFlag is null -- not edited
AND MMST.ReverseTranFlag is null -- not reversed
-- some sale transactions include time stamp that need to be removed before dates are compared; 
AND CONVERT(varchar(10), MMST.TranDate, 101) >= @ReportStartDate and  CONVERT(varchar(10), MMST.TranDate, 101) <= @ReportEndDate 


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
  FROM #tMMSTran #t
  JOIN vTranItem TI
    ON #t.MMSTranID = TI.MMSTranID
  JOIN vProduct P
    ON p.ProductID = TI.ProductID
  JOIN #Departments #D
    ON #D.DepartmentID = P.DepartmentID
  JOIN vTranItemDiscount TID
    ON TID.TranItemID = TI.TranItemID
  JOIN vPricingDiscount PD
    ON PD.PricingDiscountID = TID.PricingDiscountID
  JOIN vSalesPromotion SP
    ON PD.SalesPromotionID = SP.SalesPromotionID
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


SELECT  TI.TranItemID,
D.Description AS Department,
VR.Description AS Region,
C.ClubCode,
MMST.TranDate,
MMST.EmployeeID AS SalesEmployeeID,
E.FirstName AS SalesEmployeeFirstName,
E.LastName AS SalesEmployeeLastName,
MMST.MemberID,
M.FirstName AS MemberFirstName,
M.LastName AS MemberLastName,
CPP.ProductDescription AS Product, 
TI.ItemAmount * #PlanRate.PlanRate AS TotalSalePrice,
TI.ItemAmount AS LocalCurrency_TotalSalePrice,
TI.ItemAmount * #ToUSDPlanRate.PlanRate AS USD_TotalSalePrice,
TI.Quantity AS QuantitySold,
CASE WHEN TI.Quantity<>0 THEN (TI.ItemAmount * #PlanRate.PlanRate)/TI.Quantity ELSE 0 END AS SoldUnitPrice,
CASE WHEN TI.Quantity<>0 THEN TI.ItemAmount/TI.Quantity ELSE 0 END AS LocalCurrency_SoldUnitPrice,
CASE WHEN TI.Quantity<>0 THEN (TI.ItemAmount* #ToUSDPlanRate.PlanRate)/TI.Quantity ELSE 0 END AS USD_SoldUnitPrice,
CPP.Price * #PlanRate.PlanRate AS DefaultUnitPrice,
CPP.Price AS LocalCurrency_DefaultUnitPrice,
CPP.Price * #ToUSDPlanRate.PlanRate AS USD_DefaultUnitPrice,
CASE WHEN TI.Quantity<>0 THEN ((CPP.Price * #PlanRate.PlanRate) - ((TI.ItemAmount * #PlanRate.PlanRate)/TI.Quantity)) ELSE CPP.Price * #PlanRate.PlanRate END AS Variance,
CASE WHEN TI.Quantity<>0 THEN (CPP.Price - (TI.ItemAmount/TI.Quantity)) ELSE CPP.Price END AS LocalCurrency_Variance,
CASE WHEN TI.Quantity<>0 THEN ((CPP.Price * #ToUSDPlanRate.PlanRate) - ((TI.ItemAmount * #ToUSDPlanRate.PlanRate)/TI.Quantity)) ELSE CPP.Price * #ToUSDPlanRate.PlanRate END AS USD_Variance,
convert(varchar(10), @ReportStartDate, 101) AS ReportStartDate,
convert(varchar(10), @ReportEndDate, 101) AS ReportEndDate,
#TMP.TotalDiscountAmount * #PlanRate.PlanRate as TotalDiscountAmount,
#TMP.TotalDiscountAmount as LocalCurrency_TotalDiscountAmount,
#TMP.TotalDiscountAmount * #ToUSDPlanRate.PlanRate as USD_TotalDiscountAmount,
#TMP.AppliedDiscountAmount1 * #PlanRate.PlanRate as DiscountAmount1,
#TMP.AppliedDiscountAmount1 as LocalCurrency_DiscountAmount1,
#TMP.AppliedDiscountAmount1 * #ToUSDPlanRate.PlanRate as USD_DiscountAmount1,
#TMP.AppliedDiscountAmount2 * #PlanRate.PlanRate as DiscountAmount2,
#TMP.AppliedDiscountAmount2 as LocalCurrency_DiscountAmount2,
#TMP.AppliedDiscountAmount2 * #ToUSDPlanRate.PlanRate as USD_DiscountAmount2,
#TMP.AppliedDiscountAmount3 * #PlanRate.PlanRate as DiscountAmount3,
#TMP.AppliedDiscountAmount3 as LocalCurrency_DiscountAmount3,
#TMP.AppliedDiscountAmount3 * #ToUSDPlanRate.PlanRate as USD_DiscountAmount3,
#TMP.AppliedDiscountAmount4 * #PlanRate.PlanRate as DiscountAmount4,
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

FROM #tMMSTran MMST 
JOIN vDrawerActivity DA ON DA.DrawerActivityID = MMST.DrawerActivityID  AND DA.ValDrawerStatusID = 3 --closed drawer
JOIN vTranItem TI ON TI.MMSTranID = MMST.MMSTranID
JOIN vClubProductPriceTax CPP ON CPP.ClubID = MMST.ClubID AND CPP.ProductID = TI.ProductID  
JOIN vDepartment D ON D.DepartmentID = CPP.DepartmentID
JOIN vClub C ON C.ClubID = MMST.ClubID
JOIN vValRegion VR ON VR.ValRegionID = C.ValRegionID
JOIN vMember M ON M.MemberID = MMST.MemberID
JOIN vEmployee E ON E.EmployeeID = MMST.EmployeeID
JOIN #Clubs CS ON C.ClubID = CS.ClubID AND C.DisplayUIFlag = 1
JOIN #Departments DS ON DS.DepartmentID = D.DepartmentID
LEFT JOIN #TMPDiscount  #TMP ON #TMP.TranItemID = TI.TranItemID
/********** Foreign Currency Stuff **********/
  JOIN vValCurrencyCode VCC
       ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID
  JOIN #PlanRate
       ON VCC.CurrencyCode = #PlanRate.FromCurrencyCode
      AND YEAR(MMST.TranDate) = #PlanRate.PlanYear
  JOIN #ToUSDPlanRate
       ON VCC.CurrencyCode = #ToUSDPlanRate.FromCurrencyCode
      AND YEAR(MMST.TranDate) = #ToUSDPlanRate.PlanYear
/*******************************************/


WHERE
-- sale price is different than default price
--CPP.Price - (TI.ItemAmount/TI.Quantity) <> 0
(CASE WHEN TI.Quantity<>0 THEN (CPP.Price - (TI.ItemAmount/TI.Quantity)) ELSE CPP.Price END) <> 0
-- exclude products that do not have default price entered
AND CPP.Price <> 0


ORDER BY D.Description ASC, VR.Description ASC, C.ClubCode ASC

-- Report Logging
UPDATE HyperionReportLog
SET EndDateTime = getdate()
WHERE ReportLogID = @Identity

DROP TABLE #Clubs 
DROP TABLE #Departments
DROP TABLE #tmpList
DROP TABLE #tMMSTran
DROP TABLE #TMPDiscount
DROP TABLE #PlanRate
DROP TABLE #ToUSDPlanRate

END

