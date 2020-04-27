









-- Procedure to get production reports for mgrs
-- parameters: startdate, endate, region, account rep


CREATE  PROCEDURE dbo.mmsAcctMgrProd(
                 @StartDate SMALLDATETIME,
                 @EndDate SMALLDATETIME,
                 @RegionList VARCHAR(1000),
                 @ARList VARCHAR(1000)
)
 AS

BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

     CREATE TABLE #tmpList (StringField VARCHAR(50))
     CREATE TABLE #Regions (Description VARCHAR(50))
     --INSERT INTO #Regions (Description) exec dbo.procParseStringList @RegionList
     EXEC procParseStringList @RegionList
     INSERT INTO #Regions (Description) SELECT StringField FROM #tmpList
     TRUNCATE TABLE #tmpList

     CREATE TABLE #ARList (AccountRepInitials VARCHAR(5))
     --INSERT INTO #ARList (AccountRepInitials) exec dbo.procParseStringList @ARList
     EXEC procParseStringList @ARList
     INSERT INTO #ARList (AccountRepInitials) SELECT StringField FROM #tmpList
     TRUNCATE TABLE #tmpList

SELECT CO.AccountRepInitials AS [Account Rep], C.ClubName AS Club, MS.CancellationRequestDate,
       M.MemberID, M.JoinDate, CO.CompanyName AS Company,
       VR.Description AS RegionDescription, P.Description AS MembershipTypeDescription,
       TI.ItemAmount, M.FirstName AS MemberFirstName, M.LastName AS MemberLastName
  FROM dbo.vClub C
  JOIN dbo.vMembership MS
       ON MS.ClubID = C.ClubID
  JOIN dbo.vMember M
       ON M.MembershipID = MS.MembershipID
  JOIN dbo.vValRegion VR
       ON VR.ValRegionID = C.ValRegionID
  JOIN #Regions RS
       ON VR.Description = RS.Description
  JOIN vValMemberType VMT
       ON VMT.ValMemberTypeID = M.ValMemberTypeID
  JOIN dbo.vCompany CO
       ON MS.CompanyID = CO.CompanyID
  JOIN #ARList AR
       ON CO.AccountRepInitials = AR.AccountRepInitials
  JOIN dbo.vMembershipType MST
       ON MS.MembershipTypeID = MST.MembershipTypeID
  JOIN dbo.vProduct P
       ON P.ProductID = MST.ProductID
  JOIN dbo.vMMSTran MMST
       ON MS.MembershipID = MMST.MembershipID
  JOIN dbo.vTranItem TI
       ON MMST.MMSTranID = TI.MMSTranID
  JOIN dbo.vProduct P2
       ON TI.ProductID = P2.ProductID
 WHERE P2.ProductID = 88 AND
       VMT.Description = 'Primary' AND
       M.JoinDate BETWEEN @StartDate AND @EndDate --AND
--       VR.Description IN (SELECT Description FROM #Regions) AND
--       CO.AccountRepInitials IN (SELECT AccountRepInitials FROM #ARList)
   
DROP TABLE #tmpList

-- Report Logging
UPDATE HyperionReportLog
SET EndDateTime = getdate()
WHERE ReportLogID = @Identity

END










