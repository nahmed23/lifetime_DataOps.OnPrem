
--THIS PROCEDURE Extracts PT Revenue data by employee for a given club and payperiod.
CREATE        PROCEDURE [dbo].[mmsPTCombinedRevenueExract]
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
DECLARE @ValPTProductGroupID INT
DECLARE @Description VARCHAR(50)
DECLARE @ServiceFlag BIT
DECLARE @BatchID INT

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

--LOAD THE MISSING DATA WITH A VALUE 0

  SELECT @BatchID = MAX(BatchID)
  FROM vPTProductGroupRevenue

  SELECT DISTINCT ClubID,EmployeeID,PayPeriod
  INTO #ClubEmployee
  FROM vPTProductGroupRevenue
  WHERE PayPeriod = @PayPeriod

  SELECT ValPTProductGroupID
  INTO #PTProductGroup
  FROM vValPTProductGroup

  SELECT ClubID,EmployeeID ,PayPeriod,ValPTProductGroupID
  INTO #ClubEmployeePTProductGroup
  FROM #ClubEmployee CROSS JOIN #PTProductGroup

  INSERT INTO vPTProductGroupRevenue(ClubID,EmployeeID,PayPeriod,SalesRevenueTotal,ServiceRevenueTotal,ValPTProductGroupID,BatchID)
  SELECT CEPPG.ClubID,CEPPG.EmployeeID,CEPPG.PayPeriod,0,0,CEPPG.ValPTProductGroupID,@BatchID
  FROM #ClubEmployeePTProductGroup CEPPG LEFT JOIN vPTProductGroupRevenue PPGR ON CEPPG.ClubID = PPGR.ClubID
                                              AND CEPPG.ValPTProductgroupID = PPGR.ValPTProductgroupID
                                              AND CEPPG.EmployeeID = PPGR.EmployeeID
                                              AND CEPPG.PayPeriod = PPGR.PayPeriod
  WHERE PPGR.PTProductGroupRevenueID is null

  DROP TABLE #ClubEmployeePTProductGroup
  DROP TABLE #PTProductGroup
  DROP TABLE #ClubEmployee


--GET REVENUE TOTAL FOR ALL EMPLOYEES
CREATE TABLE #TotalRevenue(EmployeeName VARCHAR(100),EmployeeID VARCHAR(50),PayPeriod VARCHAR(50),ClubID VARCHAR(50),SalesTotal VARCHAR(50),ServiceTotal VARCHAR(50),ProductRevenueTotals Varchar(4000),SortOrder INT)

INSERT INTO #TotalRevenue(EmployeeName,EmployeeID,PayPeriod,ClubID,SalesTotal,ServiceTotal,SortOrder)
SELECT E.FirstName + ' ' + E.LastName EmployeeName,E.EmployeeID,PGR.PayPeriod,PGR.ClubID,SUM(SalesRevenueTotal) SalesTotal,
       SUM(ServiceRevenueTotal) ServiceTotal,1
FROM vPTProductGroupRevenue PGR JOIN vEmployee E ON PGR.EmployeeID = E.EmployeeID
                           JOIN vClub C ON PGR.ClubID = C.ClubID
WHERE C.ClubCode = @ClubCode
  AND PayPeriod = @PayPeriod
GROUP BY E.FirstName + ' ' + E.LastName,E.EmployeeID,PayPeriod,PGR.ClubID


--SELECT ALL AVAILABLE PRODUCTS FOR THE PAY PERIOD
SELECT Distinct PGR.ValPTProductGroupID,VPG.Description,VPG.ServiceFlag,VPG.SortOrder
INTO #ProductGroup
FROM vPTProductGroupRevenue PGR JOIN vValPTProductGroup VPG ON VPG.ValPTProductGroupID = PGR.ValPTProductGroupID
WHERE PGR.PayPeriod = @PayPeriod



--ADD SALES AND SERVICE DATA FOR ALL PRODUCTS.
WHILE (SELECT COUNT(*) FROM #ProductGroup) > 0
BEGIN

   SELECT TOP 1 @ValPTProductGroupID = ValPTProductGroupID,@Description = Description,@ServiceFlag = ServiceFlag
   FROM #ProductGroup
   ORDER BY SortOrder


   IF @ServiceFlag = 1
   BEGIN
        SET @ColumnHeader = CASE WHEN @ColumnHeader IS NULL THEN ''
                            ELSE @ColumnHeader + CHAR(9) 
                            END
                           + @Description  + ' Sales' +  CHAR(9) + @Description + ' Service'
        
        UPDATE #TotalRevenue
        SET ProductRevenueTotals = CASE WHEN ProductRevenueTotals IS NULL THEN ''
                                   ELSE ProductRevenueTotals + CHAR(9) 
                                   END + CONVERT(VARCHAR,PGR.SalesRevenueTotal) + CHAR(9) + CONVERT(VARCHAR,PGR.ServiceRevenueTotal)
        FROM #TotalRevenue TR JOIN vPTProductGroupRevenue PGR ON TR.EmployeeID = PGR.EmployeeID
                              JOIN vClub C ON PGR.ClubID = C.ClubID
        WHERE C.ClubCode = @ClubCode AND PGR.ValPTProductGroupID = @ValPTProductGroupID
          AND PGR.PayPeriod =  @PayPeriod


   END
   ELSE
   BEGIN
        SET @ColumnHeader = CASE WHEN @ColumnHeader IS NULL THEN ''
                            ELSE @ColumnHeader + CHAR(9) 
                            END
                           + @Description  + ' Sales' 

        UPDATE #TotalRevenue
        SET ProductRevenueTotals = CASE WHEN ProductRevenueTotals IS NULL THEN ''
                                   ELSE ProductRevenueTotals + CHAR(9) 
                                   END + CONVERT(VARCHAR,PGR.SalesRevenueTotal) 
        FROM #TotalRevenue TR JOIN vPTProductGroupRevenue PGR ON TR.EmployeeID = PGR.EmployeeID
                              JOIN vClub C ON PGR.ClubID = C.ClubID
        WHERE C.ClubCode = @ClubCode AND PGR.ValPTProductGroupID = @ValPTProductGroupID
          AND PGR.PayPeriod =  @PayPeriod


   END



   DELETE FROM #ProductGroup WHERE ValPTProductGroupID = @ValPTProductGroupID

END
DROP TABLE #ProductGroup

IF (SELECT COUNT(*) FROM #TotalRevenue) > 0
BEGIN
  INSERT INTO #TotalRevenue(EmployeeName,EmployeeID,PayPeriod,ClubID,SalesTotal,ServiceTotal,ProductRevenueTotals,SortOrder)
  VALUES('EmployeeName','EmployeeID','PayPeriod','ClubID','SalesTotal','ServiceTotal',@ColumnHeader,0)
END

SELECT EmployeeName,EmployeeID,ProductRevenueTotals
FROM #TotalRevenue 
ORDER BY SortOrder, EmployeeName
  
DROP TABLE #TotalRevenue

END
