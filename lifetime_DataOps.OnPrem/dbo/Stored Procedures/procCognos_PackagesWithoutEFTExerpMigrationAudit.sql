






CREATE  PROC [dbo].[procCognos_PackagesWithoutEFTExerpMigrationAudit] (
 -- @StartDate DATETIME,
 -- @EndDate DATETIME,
  @ClubIDList VARCHAR(1000),
  @DepartmentMinDimReportingHierarchyKeyList VARCHAR(8000)
)
AS
BEGIN

SET XACT_ABORT ON
SET NOCOUNT ON


IF 1=0 BEGIN
       SET FMTONLY OFF
     END

----- Sample Execution
---	Exec [procCognos_PackagesWithoutEFT]  'All Clubs', '101|120|123|142|212|213|214|220|225|220|221|222|223|281'
-----


--SET @EndDate = DATEADD(DAY,1,@EndDate) -- to include all end date transactions due to stored time


--DECLARE @HeaderDateRange VARCHAR(33) 
DECLARE @ReportRunDateTime VARCHAR(21) 

--SET @HeaderDateRange = convert(varchar(12), @StartDate, 107) + ' to ' + convert(varchar(12), @EndDate, 107)
SET @ReportRunDateTime = Replace(Substring(convert(varchar,getdate(),100),1,6)+', '+Substring(convert(varchar,GETDATE(),100),8,10)+' '+Substring(convert(varchar,getdate(),100),18,2),'  ',' ')



CREATE TABLE #tmpList (StringField VARCHAR(50))
  
  -- Parse the ClubIDs into a temp table  
CREATE TABLE #Clubs (ClubID VARCHAR(50))
IF @ClubIDList like '%All Clubs%'
  BEGIN
  INSERT INTO #Clubs (ClubID) SELECT ClubID FROM vClub
 END
 ELSE
 BEGIN 
  EXEC procParseIntegerList @ClubIDList
  INSERT INTO #Clubs (ClubID) SELECT StringField FROM #tmpList
  TRUNCATE TABLE #tmpList
 END



  
  ----- Return the hierarchy keys for the selected departments
SELECT ReportDimReportingHierarchy.DimReportingHierarchyKey,
       ReportDimReportingHierarchy.DivisionName,
       ReportDimReportingHierarchy.SubdivisionName,
       ReportDimReportingHierarchy.DepartmentName,
       ReportDimReportingHierarchy.ProductGroupName,
       ReportDimReportingHierarchy.ProductGroupSortOrder,
       ReportDimReportingHierarchy.RegionType
  INTO #DimReportingHierarchy
  FROM vReportDimReportingHierarchy BridgeTable
  JOIN fnParsePipeList(@DepartmentMinDimReportingHierarchyKeyList) KeyList
    ON BridgeTable.DimReportingHierarchyKey = KeyList.Item
  JOIN vReportDimReportingHierarchy ReportDimReportingHierarchy
    ON BridgeTable.DivisionName = ReportDimReportingHierarchy.DivisionName
   AND BridgeTable.SubdivisionName = ReportDimReportingHierarchy.SubdivisionName
   AND BridgeTable.DepartmentName = ReportDimReportingHierarchy.DepartmentName

 IF OBJECT_ID('tempdb.dbo.#SelectedProductGroup_ProductIDs', 'U') IS NOT NULL
  DROP TABLE #SelectedProductGroup_ProductIDs;

 ----- Find the list of products in the desired group
Select Product.MMSProductID, Hier.ProductGroupName 
 INTO #SelectedProductGroup_ProductIDs
FROM [dbo].[vReportDimReportingHierarchy] Hier
 JOIN [dbo].[vReportDimProduct] Product
   ON Hier.DimReportingHierarchyKey = Product.DimReportingHierarchyKey
 JOIN #DimReportingHierarchy 
   ON Product.DimReportingHierarchyKey = #DimReportingHierarchy.DimReportingHierarchyKey


---- Find the list of members who currently have an open package for a selected group's product

  IF OBJECT_ID('tempdb.dbo.#SelectedProduct_Packages', 'U') IS NOT NULL
  DROP TABLE #SelectedProduct_Packages;
 

Select MAX(PKG.PackageID) AS PackageID, 
       SUM(PKG.SessionsLeft) AS SessionsRemaining,
       PKG.MemberID, 
       PKG.MembershipID,
	   PKG.ClubID,
	   Club.ClubName,
	   PKG.ProductID,
	   Product.Description AS Product
 INTO #SelectedProduct_Packages
FROM vPackage PKG
 JOIN #SelectedProductGroup_ProductIDs Products
   ON PKG.ProductID = Products.MMSProductID
 JOIN vProduct Product
   ON PKG.ProductID = Product.ProductID
 JOIN vClub Club
   ON PKG.ClubID = Club.ClubID
 JOIN #Clubs #C 
   ON Club.ClubID = #C.ClubID
WHERE 
	PKG.SessionsLeft > 0
GROUP BY PKG.MemberID, 
       PKG.MembershipID,
	   PKG.ProductID,
	   PKG.ClubID,
	   Club.ClubName,
	   Product.Description


------ Return these package members who do not have an active recurrent product scheduled (EFT) for their current package product
SELECT @ReportRunDateTime as ReportRunDateTime,CurrentOutstandingPackages.*
FROM #SelectedProduct_Packages CurrentOutstandingPackages
LEFT JOIN [dbo].[vMembershipRecurrentProduct] EFT
   ON EFT.MemberID = CurrentOutstandingPackages.MemberID
   AND EFT.ProductID = CurrentOutstandingPackages.ProductID
   AND (EFT.TerminationDate is Null OR EFT.TerminationDate > Getdate())
    AND (CASE WHEN EFT.TerminationDate Is Null 
           THEN DateAdd(month,2,Getdate())
		   ELSE EFT.TerminationDate 
		   END) > DateAdd(month,1,(CASE WHEN EFT.ProductAssessedDateTime Is Null
		                THEN Getdate()
						ELSE EFT.ProductAssessedDateTime
						END))
Where EFT.MembershipRecurrentProductID is null
Order by CurrentOutstandingPackages.MembershipID,CurrentOutstandingPackages.MemberID




  DROP TABLE #tmpList
  DROP TABLE #Clubs
  DROP TABLE #DimReportingHierarchy



END


