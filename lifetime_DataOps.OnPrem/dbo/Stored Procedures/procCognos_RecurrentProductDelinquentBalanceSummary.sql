



CREATE PROC [dbo].[procCognos_RecurrentProductDelinquentBalanceSummary] 

AS
BEGIN 
SET XACT_ABORT ON
SET NOCOUNT ON

DECLARE @ReportRunDateTime DateTime
SELECT @ReportRunDateTime = GetDate()


 ----- To collect Membership product balances where there are no TranItemIDs (older than 120 days delinquent)
SELECT MS.ClubID, 
       MS.MembershipID,
       'Untracked Product - older than 120 days' AS MMSDepartment,
	   'Untracked Product - older than 120 days' AS ProductDescription,
       TB.TranBalanceAmount
  INTO #OutstandingProductBalance_Old
  FROM vTranBalance TB
   JOIN vMembership MS
     ON TB.MembershipID = MS.MembershipID
  WHERE TB.TranProductCategory = 'Products'
    AND TB.TranBalanceAmount > 0
    AND IsNull(TB.TranItemID,0) = 0


  
  ----- to collect tranIDs into a temp table for those delinquencies less than 120 days delinquent
SELECT  TranItemID, TranBalanceAmount
  INTO #TranItemIDs
  FROM vTranBalance 
  WHERE TranProductCategory = 'Products'
    AND TranBalanceAmount > 0
    AND IsNull(TranItemID,0) <> 0


  --- collect information on packages for TranItems related to packages
SELECT TranIDs.TranItemID, 
       TranIDs.TranBalanceAmount,
       PKG.ClubID,
	   D.Description AS MMSDepartment, 
	   P.Description AS ProductDescription,
	   PKG.PackageID, 
	   PKG.NumberOfSessions,
	   PKG.PricePerSession, 
	   PKG.CreatedDateTime,
	   PKG.SessionsLeft,
	   PKG.MembershipID,
	   TI.ItemSalesTax,
	   TI.ItemAmount
INTO #DelinquentPackages
 FROM vPackage PKG
 JOIN #TranItemIDs TranIDs
   ON PKG.TranItemID = TranIDs.TranItemID
 JOIN vTranItem TI
   ON TranIDs.TranItemID = TI.TranItemID
 JOIN vProduct P
   ON TI.ProductID = P.ProductID
 JOIN vDepartment D
   ON P.DepartmentID = D.DepartmentID



  --- to collect information on products which are not packages
SELECT MT.ClubID, 
       MT.MembershipID,
	   D.Description AS MMSDepartment, 
	   P.Description AS ProductDescription,
	   SUM(TI.ItemAmount) AS OriginalTranAmount,
	   SUM(TI.ItemSalesTax) AS OriginalSalesTaxAmount,
       SUM(TranIDs.TranBalanceAmount) AS TranBalanceAmount
INTO #DelinquentProductsNotPackages
 FROM #TranItemIDs TranIDs
 JOIN vTranItem TI
   ON TranIDs.TranItemID = TI.TranItemID
 JOIN vProduct P
   ON TI.ProductID = P.ProductID
 JOIN vDepartment D
   ON P.DepartmentID = D.DepartmentID
 JOIN vMMSTran MT
   ON TI.MMSTranID = MT.MMSTranID
 LEFT JOIN #DelinquentPackages PKG
   ON PKG.TranItemID = TranIDs.TranItemID
WHERE IsNull(PKG.TranItemID,0) = 0
GROUP BY MT.ClubID,
       MT.MembershipID, 
	   D.Description, 
	   P.Description


  --- to sum by package any adjustments on delinquent packages
SELECT  PKG.PackageID, 
       SUM(PKGAdjustments.SessionsAdjusted) AS SessionsAdjustedCount,
       SUM(PKGAdjustments.AmountAdjusted) AS SessionsAdjustedPrice
 INTO #AdjustedPackages
   FROM #DelinquentPackages PKG
   JOIN vPackageAdjustment PKGAdjustments
     ON PKG.PackageID = PKGAdjustments.PackageID
   GROUP BY PKG.PackageID


 ---- to sum by package any delivered sessions on delinquent packages
SELECT PKG.PackageID,
       COUNT(PKGSessions.PackageSessionID) AS SessionsDelivered,
	   SUM(PKGSessions.SessionPrice) AS SessionsDeliveredPrice
 INTO #DeliveredSessions
  FROM #DelinquentPackages PKG
  JOIN vPackageSession PKGSessions
    ON PKG.PackageID = PKGSessions.PackageID
  GROUP BY PKG.PackageID



  ---- to pull information on delinquent packages into a single result set unioned with records for non-package and older delinquent products
SELECT  DelPkg.ClubID,
   Club.ClubName,
   Region.Description AS Region, 
   DelPkg.PackageID,
   DelPkg.MMSDepartment, 
   DelPkg.ProductDescription,
   DelPkg.CreatedDateTime AS PackageCreatedDateTime,
   DelPkg.NumberOfSessions AS PackageOriginalSessions,
   DelPkg.MembershipID,
   (DelPkg.ItemAmount + DelPkg.ItemSalesTax) AS OriginalTranAmount,
   DelPkg.TranBalanceAmount AS OutstandingAmount,
   PKGSession.SessionsDelivered AS SessionsDeliveredCount,
   PKGSession.SessionsDeliveredPrice AS SessionsDeliveredAmount,
   PKGAdjustments.SessionsAdjustedCount,
   PKGAdjustments.SessionsAdjustedPrice AS SessionsAdjustedAmount,
   MSStatus.Description AS MembershipStatus,
   @ReportRunDateTime AS ReportRunDateTime
FROM #DelinquentPackages DelPkg
 LEFT JOIN #DeliveredSessions PKGSession
   ON DelPkg.PackageID = PKGSession.PackageID
 LEFT JOIN #AdjustedPackages PKGAdjustments
   ON DelPkg.PackageID = PKGAdjustments.PackageID
 JOIN vMembership MS
   ON DelPkg.MembershipID = MS.MembershipID
 JOIN vValMembershipStatus MSStatus
   ON MS.ValMembershipStatusID = MSStatus.ValMembershipStatusID
 JOIN vClub Club
   ON DelPkg.ClubID = Club.ClubID
 JOIN vValRegion Region
   ON Club.ValRegionID = Region.ValRegionID

   UNION ALL

SELECT  Old.ClubID, 
   Club.ClubName,
   Region.Description AS Region, 
   NULL AS PackageID,
   Old.MMSDepartment, 
   Old.ProductDescription,
   NULL  AS PackageCreatedDateTime,
   NULL AS PackageOriginalSessions,
   Old.MembershipID,
   NULL AS OriginalTranAmount,
   Old.TranBalanceAmount AS OutstandingAmount,
   NULL AS SessionsDeliveredCount,
   NULL AS SessionsDeliveredAmount,
   NULL AS SessionsAdjustedCount,
   NULL AS SessionsAdjustedAmount,
   MSStatus.Description AS MembershipStatus,
   @ReportRunDateTime AS ReportRunDateTime
 FROM #OutstandingProductBalance_Old  Old
  JOIN vMembership MS
    ON Old.MembershipID = MS.MembershipID
  JOIN vValMembershipStatus MSStatus
    ON MS.ValMembershipStatusID = MSStatus.ValMembershipStatusID
  JOIN vClub Club
    ON Old.ClubID = Club.ClubID
  JOIN vValRegion Region
    ON Club.ValRegionID = Region.ValRegionID

   UNION ALL

SELECT  NonPkg.ClubID,
   Club.ClubName,
   Region.Description AS Region,  
   NULL AS PackageID,
   NonPkg.MMSDepartment, 
   NonPkg.ProductDescription,
   NULL  AS PackageCreatedDateTime,
   NULL AS PackageOriginalSessions,
   NonPkg.MembershipID,
   (NonPkg.OriginalTranAmount + NonPkg.OriginalSalesTaxAmount) AS OriginalTranAmount,
   NonPkg.TranBalanceAmount AS OutstandingAmount,
   NULL AS SessionsDeliveredCount,
   NULL AS SessionsDeliveredAmount,
   NULL AS SessionsAdjustedCount,
   NULL AS SessionsAdjustedAmount,
   MSStatus.Description AS MembershipStatus,
   @ReportRunDateTime AS ReportRunDateTime
 FROM #DelinquentProductsNotPackages  NonPkg
   JOIN vMembership MS
     ON NonPkg.MembershipID = MS.MembershipID
   JOIN vValMembershipStatus MSStatus
     ON MS.ValMembershipStatusID = MSStatus.ValMembershipStatusID
   JOIN vClub Club
     ON NonPkg.ClubID = Club.ClubID
   JOIN vValRegion Region
     ON Club.ValRegionID = Region.ValRegionID


   DROP TABLE #TranItemIDs
   DROP TABLE #AdjustedPackages
   DROP TABLE #OutstandingProductBalance_Old
   DROP TABLE #DelinquentPackages
   DROP TABLE #DeliveredSessions
   DROP TABLE #DelinquentProductsNotPackages
END
