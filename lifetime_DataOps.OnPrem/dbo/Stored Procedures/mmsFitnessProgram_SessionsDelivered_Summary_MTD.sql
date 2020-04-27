/*    =============================================
Object:            dbo.mmsFitnessProgram_SessionsDelivered_Summary_MTD
Author:            Greg Burdick
Create date:     10/21/2010
Description:    This query aggregates delivered sessions within a specified date range.
Modified date:    10/22/2010 BSD: Initial procedure 
                11/18/2011 BSD: Added logging
                2/22/2012 BSD: Converting values to USD QC#1750
    =============================================    */

CREATE PROCEDURE [dbo].[mmsFitnessProgram_SessionsDelivered_Summary_MTD]

AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

DECLARE @StartDate DATETIME
DECLARE    @EndDate DATETIME

SET @StartDate = DATEADD(mm,DATEDIFF(mm,0,DATEADD(dd,-1,getdate())),0)
SET @EndDate =    CONVERT(DATETIME,CONVERT(VARCHAR,getdate(),101))

CREATE TABLE #DeliveredSessionsDetail    (
    StartDate DATETIME,
    EndDate DATETIME,
    Clubid INT, 
    Clubname VARCHAR(50), 
    DeliveredEmployeeID INT,
    EmployeeFirstname VARCHAR(50), 
    EmployeeLastname VARCHAR(50),
    SessionID INT, 
    Productid INT,
    ProductDescription VARCHAR(50), 
    DeliveredSessionUnits NUMERIC(11,1),
    DeliveredSessionAmount NUMERIC(12,2))
INSERT INTO #DeliveredSessionsDetail
SELECT @StartDate,
       @EndDate,
       C.Clubid, 
       C.Clubname, 
       S.DeliveredEmployeeID,
       E.Firstname [EmployeeFirstname], 
       E.Lastname [EmployeeLastname],
       S.Packagesessionid [SessionID], 
       P.Productid,
       P.Description [ProductDescription], 
       CASE WHEN P.Description LIKE '%30 minute%' THEN 0.5
            ELSE 1
        END [DeliveredSessionUnits],
       S.Sessionprice * ToUSDPlanExchangeRate.PlanExchangeRate [DeliveredSessionAmount] --BSD 2/22/2012 QC#1750
  FROM dbo.vPackagesession S
  JOIN dbo.vClub C
    ON S.Clubid = C.Clubid
  JOIN dbo.vEmployee E
    ON S.Deliveredemployeeid = E.Employeeid
  JOIN dbo.vPackage PKG
    ON S.Packageid = PKG.Packageid
  JOIN dbo.vProduct P
    ON PKG.Productid = P.Productid
  JOIN vValCurrencyCode VCC --BSD 2/22/2012 QC#1750
    ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID
  JOIN vPlanExchangeRate ToUSDPlanExchangeRate --BSD 2/22/2012 QC#1750
    ON VCC.CurrencyCode = ToUSDPlanExchangeRate.FromCurrencyCode
   AND 'USD' = ToUSDPlanExchangeRate.ToCurrencyCode
   AND YEAR(@StartDate) = ToUSDPlanExchangeRate.PlanYear
WHERE S.Delivereddatetime >= @StartDate 
   AND S.Delivereddatetime < @EndDate

ORDER BY C.Clubid, S.DeliveredEmployeeID, P.Productid


--    Summarize to ClubEmployeeProduct level
CREATE TABLE #DeliveredSessionsSummary    (
    Clubid INT, 
    Clubname VARCHAR(50), 
    DeliveredEmployeeID INT,
    EmployeeFirstname VARCHAR(50), 
    EmployeeLastname VARCHAR(50),
    Productid INT,
    ProductDescription VARCHAR(50), 
    DeliveredSessionUnits NUMERIC(11,1),
    DeliveredSessionAmount NUMERIC(12,2))
INSERT INTO #DeliveredSessionsSummary
SELECT Clubid, 
       Clubname, 
       DeliveredEmployeeID,
       EmployeeFirstname, 
       EmployeeLastname,
       Productid,
       ProductDescription, 
       SUM(DeliveredSessionUnits) [DeliveredSessionUnits],
       SUM(DeliveredSessionAmount)[DeliveredSessionAmount]
  FROM #DeliveredSessionsDetail
 GROUP BY Clubid,
          Clubname, 
          DeliveredEmployeeID,
          EmployeeFirstname, 
          EmployeeLastname, 
          Productid,
          ProductDescription
 ORDER BY Clubid, DeliveredEmployeeID, Productid


SELECT Clubid, 
       Clubname, 
       DeliveredEmployeeID,
       EmployeeFirstname, 
       EmployeeLastname,
       Productid,
       ProductDescription, 
       DeliveredSessionUnits,
       DeliveredSessionAmount
  FROM #DeliveredSessionsSummary
 ORDER BY Clubid, DeliveredEmployeeID, Productid


DROP TABLE #DeliveredSessionsDetail
DROP TABLE #DeliveredSessionsSummary

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity


END
