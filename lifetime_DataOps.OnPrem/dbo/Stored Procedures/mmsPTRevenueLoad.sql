

--THIS PROCEDURE retuens PT Revenue data for a given payperiod.
CREATE        PROCEDURE [dbo].[mmsPTRevenueLoad]
 (
  @PayPeriodOffSet INT,
  @BatchID INT
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON 

DECLARE @ClubID INT
DECLARE @ProductGroupID INT
DECLARE @BeginDate DATETIME
DECLARE @EndDate DATETIME
DECLARE @ProcessDate DATETIME
DECLARE @PayPeriod  VARCHAR(7)

SET @ProcessDate = DATEADD(DD,-1,GETDATE())

--FIND the begin and enddates
IF @PayPeriodOffSet = 0
BEGIN
   IF DAY(@ProcessDate) < 16  
   BEGIN
     SET @BeginDate = CONVERT(VARCHAR,MONTH(@ProcessDate)) + '/01/' + CONVERT(VARCHAR,YEAR(@ProcessDate))
     SET @EndDate = CONVERT(VARCHAR,MONTH(@ProcessDate)) + '/16/' + CONVERT(VARCHAR,YEAR(@ProcessDate))
     SET @PayPeriod = CONVERT(VARCHAR,YEAR(@ProcessDate)) + 
                      CASE WHEN LEN(CONVERT(VARCHAR,MONTH(@ProcessDate))) = 1 THEN '0' + CONVERT(VARCHAR,MONTH(@ProcessDate))
                      ELSE CONVERT(VARCHAR,MONTH(@ProcessDate))
                      END +
                      '1'
   END
   ELSE
   BEGIN
     SET @BeginDate = CONVERT(VARCHAR,MONTH(@ProcessDate)) + '/16/' + CONVERT(VARCHAR,YEAR(@ProcessDate))
     SET @EndDate = CONVERT(VARCHAR,MONTH(DATEADD(MM,1,@ProcessDate))) + '/01/' + CONVERT(VARCHAR,YEAR(DATEADD(MM,1,@ProcessDate)))
     SET @PayPeriod = CONVERT(VARCHAR,YEAR(@ProcessDate)) + 
                      CASE WHEN LEN(CONVERT(VARCHAR,MONTH(@ProcessDate))) = 1 THEN '0' + CONVERT(VARCHAR,MONTH(@ProcessDate))
                      ELSE CONVERT(VARCHAR,MONTH(@ProcessDate))
                      END +
                      '2'
   END
END
ELSE
BEGIN
   IF DAY(@ProcessDate) < 16  
   BEGIN
     SET @BeginDate = CONVERT(VARCHAR,MONTH(DATEADD(MM,-1,@ProcessDate))) + '/16/' + CONVERT(VARCHAR,YEAR(DATEADD(MM,-1,@ProcessDate)))
     SET @EndDate = CONVERT(VARCHAR,MONTH(@ProcessDate)) + '/01/' + CONVERT(VARCHAR,YEAR(@ProcessDate))
     SET @PayPeriod = CONVERT(VARCHAR,YEAR(DATEADD(MM,-1,@ProcessDate))) + 
                      CASE WHEN LEN(CONVERT(VARCHAR,MONTH(DATEADD(MM,-1,@ProcessDate)))) = 1 THEN '0' + CONVERT(VARCHAR,MONTH(DATEADD(MM,-1,@ProcessDate)))
                      ELSE CONVERT(VARCHAR,MONTH(DATEADD(MM,-1,@ProcessDate)))
                      END +
                      '2'
   END
   ELSE
   BEGIN
     SET @BeginDate = CONVERT(VARCHAR,MONTH(@ProcessDate)) + '/01/' + CONVERT(VARCHAR,YEAR(@ProcessDate))
     SET @EndDate = CONVERT(VARCHAR,MONTH(@ProcessDate)) + '/16/' + CONVERT(VARCHAR,YEAR(@ProcessDate))
     SET @PayPeriod = CONVERT(VARCHAR,YEAR(@ProcessDate)) + 
                      CASE WHEN LEN(CONVERT(VARCHAR,MONTH(@ProcessDate))) = 1 THEN '0' + CONVERT(VARCHAR,MONTH(@ProcessDate))
                      ELSE CONVERT(VARCHAR,MONTH(@ProcessDate))
                      END +
                      '1'

   END
END

SELECT ClubID
INTO #Club
FROM vClub
WHERE DisplayUIflag = 1
  AND ValPreSaleID NOT IN(4)

CREATE TABLE #PTRevenue(ClubID INT,EmployeeID INT,ValPTProductGroupID INT,PayPeriod VARCHAR(10),SalesTotal NUMERIC(10,2),ServiceTotal NUMERIC(10,2),BatchID INT)

  --DELETE FROM vPTOneOnOneRevenue FOR THE GIVEN PAYPERIOD

   DELETE 
   FROM vPTProductGroupRevenue
   WHERE PayPeriod = @PayPeriod


SET @ClubID = (SELECT TOP 1 ClubID FROM #Club ORDER BY 1)

WHILE (SELECT COUNT(*) FROM #Club) > 0 AND @ClubID IS NOT NULL 
BEGIN

   DELETE FROM #Club WHERE ClubID = @ClubID

   --SELECT @ProductGroupID = ValProductGroupID
   --FROM vValProductGroup
   --WHERE Description = 'PTOneOnOne Revenue'

   --SELECT ALL COMMISSIONABLE EMPLOYEES FOR THE CLUB THAT ARE ACTIVE
   SELECT DISTINCT E.EmployeeID
   INTO #Employee
   FROM vEmployee E JOIN vEmployeeRole ER ON E.EmployeeID = ER.EmployeeID
                    JOIN vValEmployeeRole VER ON ER.ValEmployeeRoleID = VER.ValEmployeeRoleID
   WHERE VER.CommissionableFlag = 1
     AND E.ClubID = @ClubID
     AND E.ActiveStatusFlag = 1
 
   --SELECT ALL COMMISSIONABLE PRODUCTS
   SELECT ProductID
   INTO #Product
   FROM vPTProductGroup
--   WHERE ValProductGroupID = @ProductGroupID

   --SELECT ALL COMMISSIONABLE SALE TRANSACTIONS AMOUNTS


   SELECT TI.TranItemID,P.ProductID,MIN(SC.SaleCommissionID) SaleCommissionID
   INTO #SaleCommission
   FROM vMMSTran MT JOIN vTranItem TI ON MT.MMSTranID = TI.MMStranID
                    JOIN #Product P ON TI.ProductID = P.ProductID
                    JOIN vSaleCommission SC ON TI.TranItemID = SC.TranItemID
   WHERE TranDate >= @BeginDate AND TranDate < @EndDate
     AND MT.ClubID = @ClubID
     AND MT.TranVoidedID IS NULL 
     AND ISNULL(MT.ReverseTranFlag,0) = 0 
     AND ISNULL(MT.TranEditedFlag,0) = 0
   GROUP BY TI.TranItemID,P.ProductID

   --SELECT E.EmployeeID,MT.POSAmount,SC.SaleCommissionID,TI.TranItemID,P.ProductID
   SELECT TI.TranItemID,P.ProductID,SUM(TI.ItemAmount) POSAmount,MIN(SC.SaleCommissionID) SaleCommissionID
   INTO #Sales
   FROM vMMSTran MT JOIN vTranItem TI ON MT.MMSTranID = TI.MMStranID
                    JOIN #Product P ON TI.ProductID = P.ProductID
                    JOIN #SaleCommission SC ON TI.TranItemID = SC.TranItemID
   WHERE TranDate >= @BeginDate AND TranDate < @EndDate
     AND MT.ClubID = @ClubID
     AND MT.TranVoidedID IS NULL 
     AND ISNULL(MT.ReverseTranFlag,0) = 0 
     AND ISNULL(MT.TranEditedFlag,0) = 0
   GROUP BY TI.TranItemID,P.ProductID

   --GROUP ALL SALES BY EMPLOYEE AND PRODUCT
   SELECT SC.EmployeeID,PPG.ValPTProductGroupID,SUM(S.POSAmount) POSAmount
   INTO #EmployeeSales
   FROM #Sales S JOIN vSaleCommission SC ON S.SaleCommissionID = SC.SaleCommissionID
                 JOIN vPTProductGroup PPG ON S.ProductID = PPG.ProductID
   GROUP BY SC.EmployeeID,PPG.ValPTProductGroupID

   --SELECT ALL COMMISSIONABLE SERVICES
   SELECT PS.DeliveredEmployeeID EmployeeID,VPPG.ValPTProductGroupID,SUM(PS.SessionPrice) ServiceTotal
   INTO #EmployeeService
   FROM vPackage PK JOIN vPackageSession PS ON PK.PackageID = PS.PackageID
                   JOIN #Product P ON PK.ProductID = P.ProductID
                   JOIN vPTProductGroup PPG ON P.ProductID = PPG.ProductID
                   JOIN vValPTProductGroup VPPG ON PPG.ValPTProductGroupID = VPPG.ValPTProductGroupID
   WHERE PS.CreatedDateTime >= @BeginDate 
     AND PS.CreatedDateTime < @EndDate
     AND ValPackageStatusID <> 4 --PACKAGES THAT ARE NOT VOIDED
     AND PS.ClubID = @ClubID
     AND VPPG.ServiceFlag = 1
   GROUP BY PS.DeliveredEmployeeID,VPPG.ValPTProductGroupID


   --INSERT INTO #EMPLOYEE ALL EMPLOYEES FROM OTHER CLUBS THAT HAVE COMMISSIONABLE SALE
   INSERT INTO #Employee(EmployeeID)
   SELECT DISTINCT EmployeeID 
   FROM #EmployeeSales 
   WHERE EmployeeID NOT IN(SELECT EmployeeID FROM #Employee)

   --INSERT INTO #EMPLOYEE ALL EMPLOYEES FROM OTHER CLUBS THAT HAVE COMMISSIONABLE SERVICES
   INSERT INTO #Employee(EmployeeID)
   SELECT DISTINCT EmployeeID 
   FROM #EmployeeService 
   WHERE EmployeeID NOT IN(SELECT EmployeeID FROM #Employee)

   --CROSS JOINS ALL PRODUCTS AND EMPLOYEES
   SELECT EmployeeID,ValPTProductGroupID
   INTO #EmployeeProductGroup
   FROM #Employee CROSS JOIN vValPTProductGroup 


   --SELECT TOTAL SALES BY EMPLOYEE AND PRODUCT
   INSERT INTO #PTRevenue(ClubID,EmployeeID,ValPTProductGroupID,PayPeriod,SalesTotal,ServiceTotal,BatchID)
   SELECT @ClubID ClubID,EP.EmployeeID,EP.ValPTProductGroupID,@PayPeriod PayPeriod,ISNULL(ES.POSAmount,0) SalesTotal, ISNULL(ESR.ServiceTotal,0) ServiceTotal,@BatchID
   FROM #EmployeeProductGroup EP LEFT JOIN #EmployeeSales ES ON EP.EmployeeID = ES.EmployeeID AND EP.ValPTProductGroupID = ES.ValPTProductGroupID
                                 LEFT JOIN #EmployeeService ESR ON EP.EmployeeID = ESR.EmployeeID AND EP.ValPTProductGroupID = ESR.ValPTProductGroupID


   SET @ClubID = NULL
   SET @ClubID = (SELECT TOP 1 ClubID FROM #Club ORDER BY 1)
   

   DROP TABLE #Employee
   DROP TABLE #Product
   DROP TABLE #EmployeeProductGroup
   DROP TABLE #EmployeeSales
   DROP TABLE #EmployeeService
   DROP TABLE #Sales
   DROP TABLE #SaleCommission
     
   
END

SELECT ClubID,EmployeeID,ValPTProductGroupID,PayPeriod,SalesTotal,ServiceTotal,BatchID
FROM #PTRevenue
DROP TABLE #Club
DROP TABLE #PTRevenue


END
