CREATE    PROC [dbo].[mmsPackage_DeliveredMindBodySessions_MTD_AllClubs]
---- This query returns delivered sessions within a selected date range.
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

DECLARE @ClubIDs VARCHAR(1000)
DECLARE @FirstOfMonth DATETIME
DECLARE @Today 	DATETIME

SET @FirstOfMonth = CONVERT(DATETIME,CONVERT(VARCHAR,(GETDATE() - DAY(GETDATE()-1)),110),110)
SET @Today = CONVERT(DATETIME,CONVERT(VARCHAR,GETDATE(),110),110)
SET @ClubIDs = 'All'

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

CREATE TABLE #tmpList(StringField VARCHAR(50))

IF (@ClubIDs = 'All') 	SET @ClubIDs=0
---- Parse the ClubIDs into a temp table
EXEC procParseIntegerList @ClubIDs
CREATE TABLE #Clubs(ClubID INT)
INSERT INTO #Clubs(ClubID) SELECT StringField FROM #tmpList


SELECT RC.Clubname AS RevenueClub, RC.Clubid AS RevenueClubID, E.Employeeid,
       E.Firstname AS EmployeeFirstname, E.Lastname AS EmployeeLastname,
       S.Packagesessionid AS SessionID, 
       S.Sessionprice * ToUSDPlanExchangeRate.PlanExchangeRate SessionPrice, --BSD 2/22/2012 QC#1750
       P.Productid, 
       P.Description AS ProductDescription, M.Memberid, M.Firstname AS MemberFirstname, 
       M.Lastname AS MemberLastname,  VPS.Description AS PackageStatusDescription, 
       PKG.Packageid, S.Delivereddatetime,SC.Clubname AS SaleClub, SC.Clubid AS SaleClubid,
       R.Description AS RegionDescription,S.Comment, EC.ClubName AS EmployeeHomeClub,
       CASE WHEN P.Productid IN(1858,1859) THEN 1 ----- 30 minute session products
            ELSE 0 END Half_Session_Flag,
       P.DepartmentID AS ProductDeptID, @Today AS ReportingEndDateTime, 
       PKG.CreatedDateTime AS PackageCreatedDate
  FROM dbo.vPackagesession S
  JOIN dbo.vClub RC
    ON S.Clubid = RC.Clubid
  JOIN #Clubs tC
    ON (RC.Clubid = tC.ClubID OR tC.ClubID = 0)
  JOIN dbo.vValRegion R
    ON RC.Valregionid = R.ValRegionID
  JOIN dbo.vEmployee E
    ON S.Deliveredemployeeid = E.Employeeid
  JOIN dbo.vClub EC
    ON E.ClubID = EC.ClubID  ---- To Get Employee Home Club
  JOIN dbo.vPackage PKG
    ON S.Packageid = PKG.Packageid
  JOIN dbo.vMember M
    ON PKG.Memberid = M.Memberid
  JOIN dbo.vProduct P
    ON PKG.Productid = P.Productid  
  JOIN dbo.vValpackagestatus VPS
    ON PKG.Valpackagestatusid = VPS.Valpackagestatusid
  JOIN dbo.vClub SC
    ON PKG.Clubid = SC.Clubid
  JOIN vValCurrencyCode VCC --BSD 2/22/2012 QC#1750
    ON SC.ValCurrencyCodeID = VCC.ValCurrencyCodeID
  JOIN vPlanExchangeRate ToUSDPlanExchangeRate --BSD 2/22/2012 QC#1750
    ON VCC.CurrencyCode = ToUSDPlanExchangeRate.FromCurrencyCode
   AND 'USD' = ToUSDPlanExchangeRate.ToCurrencyCode
   AND YEAR(@FirstOfMonth) = ToUSDPlanExchangeRate.PlanYear
 WHERE S.Delivereddatetime >= @FirstOfMonth 
   AND S.Delivereddatetime <= @Today 
   AND P.DepartmentID=10 -- Mind Body
	

DROP TABLE #Clubs
DROP TABLE #TmpList

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END
