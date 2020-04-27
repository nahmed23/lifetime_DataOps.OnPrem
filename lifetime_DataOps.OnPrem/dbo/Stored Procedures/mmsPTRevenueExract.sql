


--THIS PROCEDURE Extracts PT Revenue data by employee for a given club and payperiod.
CREATE        PROCEDURE dbo.mmsPTRevenueExract
 (
  @PayPeriodOffSet INT,
  @ClubCode VARCHAR(3)
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON 

DECLARE @ExtractDate DATETIME
DECLARE @PayPeriod  VARCHAR(7)
DECLARE @EmployeeID INT
DECLARE @ColumnHeader VARCHAR(4000)
DECLARE @ProductID INT
DECLARE @Description VARCHAR(50)

SET @ExtractDate = DATEADD(DD,-1,GETDATE())

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

--FIND the PAYPERIOD
IF @PayPeriodOffSet = 0
BEGIN
   IF DAY(@ExtractDate) < 16  
   BEGIN
     SET @PayPeriod = CONVERT(VARCHAR,YEAR(@ExtractDate)) + 
                      CASE WHEN LEN(CONVERT(VARCHAR,MONTH(@ExtractDate))) = 1 THEN '0' + CONVERT(VARCHAR,MONTH(@ExtractDate))
                      ELSE CONVERT(VARCHAR,MONTH(@ExtractDate))
                      END +
                      '1'
   END
   ELSE
   BEGIN
     SET @PayPeriod = CONVERT(VARCHAR,YEAR(@ExtractDate)) + 
                      CASE WHEN LEN(CONVERT(VARCHAR,MONTH(@ExtractDate))) = 1 THEN '0' + CONVERT(VARCHAR,MONTH(@ExtractDate))
                      ELSE CONVERT(VARCHAR,MONTH(@ExtractDate))
                      END +
                      '2'
   END
END
ELSE
BEGIN
   IF DAY(@ExtractDate) < 16  
   BEGIN
     SET @PayPeriod = CONVERT(VARCHAR,YEAR(DATEADD(MM,-1,@ExtractDate))) + 
                      CASE WHEN LEN(CONVERT(VARCHAR,MONTH(DATEADD(MM,-1,@ExtractDate)))) = 1 THEN '0' + CONVERT(VARCHAR,MONTH(DATEADD(MM,-1,@ExtractDate)))
                      ELSE CONVERT(VARCHAR,MONTH(DATEADD(MM,-1,@ExtractDate)))
                      END +
                      '2'
   END
   ELSE
   BEGIN
     SET @PayPeriod = CONVERT(VARCHAR,YEAR(@ExtractDate)) + 
                      CASE WHEN LEN(CONVERT(VARCHAR,MONTH(@ExtractDate))) = 1 THEN '0' + CONVERT(VARCHAR,MONTH(@ExtractDate))
                      ELSE CONVERT(VARCHAR,MONTH(@ExtractDate))
                      END +
                      '1'

   END
END


--GET REVENUE TOTAL FOR ALL EMPLOYEES
CREATE TABLE #TotalRevenue(EmployeeName VARCHAR(100),EmployeeID VARCHAR(50),PayPeriod VARCHAR(50),ClubID VARCHAR(50),SalesTotal VARCHAR(50),ServiceTotal VARCHAR(50),ProductRevenueTotals Varchar(4000),SortOrder INT)

INSERT INTO #TotalRevenue(EmployeeName,EmployeeID,PayPeriod,ClubID,SalesTotal,ServiceTotal,SortOrder)
SELECT E.FirstName + ' ' + E.LastName EmployeeName,E.EmployeeID,PR.PayPeriod,PR.ClubID,SUM(SalesTotal) SalesTotal,
       SUM(ServiceRevenueTotal) ServiceTotal,1
FROM vPTOneOnOneRevenue PR JOIN vEmployee E ON PR.EmployeeID = E.EmployeeID
                           JOIN vClub C ON PR.ClubID = C.ClubID
WHERE C.ClubCode = @ClubCode
  AND PayPeriod = @PayPeriod
GROUP BY E.FirstName + ' ' + E.LastName,E.EmployeeID,PayPeriod,PR.ClubID


--SELECT ALL AVAILABLE PRODUCTS FOR THE PAY PERIOD
SELECT Distinct PR.ProductID,P.Description
INTO #Product
FROM vPTOneOnOneRevenue PR JOIN vProduct P ON P.ProductID = PR.ProductID
WHERE PR.PayPeriod = @PayPeriod


--ADD SALES AND SERVICE DATA FOR ALL PRODUCTS.
WHILE (SELECT COUNT(*) FROM #Product) > 0
BEGIN

   SELECT TOP 1 @ProductID = ProductID,@Description = Description
   FROM #Product
   ORDER BY 2

   SET @ColumnHeader = CASE WHEN @ColumnHeader IS NULL THEN ''
                       ELSE @ColumnHeader + CHAR(9) 
                       END
                       + @Description  + ' Sales' +  CHAR(9) + @Description + ' Service'

   UPDATE #TotalRevenue
   SET ProductRevenueTotals = CASE WHEN ProductRevenueTotals IS NULL THEN ''
                              ELSE ProductRevenueTotals + CHAR(9) 
                              END + CONVERT(VARCHAR,PR.SalesTotal) + CHAR(9) + CONVERT(VARCHAR,PR.ServiceRevenueTotal)
   FROM #TotalRevenue TR JOIN vPTOneOnOneRevenue PR ON TR.EmployeeID = PR.EmployeeID
                               JOIN vClub C ON PR.ClubID = C.ClubID
                   WHERE C.ClubCode = @ClubCode AND PR.ProductID = @ProductID
                       AND PR.PayPeriod =  @PayPeriod


   DELETE FROM #Product WHERE ProductID = @ProductID

END
DROP TABLE #Product

IF (SELECT COUNT(*) FROM #TotalRevenue) > 0
BEGIN
  INSERT INTO #TotalRevenue(EmployeeName,EmployeeID,PayPeriod,ClubID,SalesTotal,ServiceTotal,ProductRevenueTotals,SortOrder)
  VALUES('EmployeeName','EmployeeID','PayPeriod','ClubID','SalesTotal','ServiceTotal',@ColumnHeader,0)
END

SELECT EmployeeName,EmployeeID,PayPeriod,ClubID,SalesTotal,ServiceTotal,ProductRevenueTotals
FROM #TotalRevenue 
ORDER BY SortOrder, EmployeeName
  
DROP TABLE #TotalRevenue


-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END




