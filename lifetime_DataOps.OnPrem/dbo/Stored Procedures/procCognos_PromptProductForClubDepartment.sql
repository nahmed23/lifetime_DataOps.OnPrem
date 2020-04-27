
------------------------------------------------------------------------------------------------------------------------
/*
-- returns the products available at a given clubs department
--
-- Parameters: A | separated list of clubs and a similar departments list
 exec procCognos_PromptProductForClubDepartment '151', '220'
*/

CREATE PROC [dbo].[procCognos_PromptProductForClubDepartment] (
  @ClubIDList VARCHAR(8000),
  @DepartmentMinDimReportingHierarchyKeyList VARCHAR(1000)
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON
CREATE TABLE #tmpList (StringField VARCHAR(50))
CREATE TABLE #Clubs (ClubID INT)


IF @ClubIDList <> 'All'

BEGIN
   EXEC procParseIntegerList @ClubIDList
   INSERT INTO #Clubs (ClubID) SELECT CONVERT(INT,StringField) FROM #tmpList
   TRUNCATE TABLE #tmpList
END
ELSE
BEGIN
  INSERT INTO #Clubs (ClubID) SELECT ClubID FROM vClub 
END

CREATE TABLE #Departments (DimReportingHierarchyKey INT)
   EXEC procParseIntegerList @DepartmentMinDimReportingHierarchyKeyList
   INSERT INTO #Departments (DimReportingHierarchyKey) SELECT StringField FROM #tmpList
   TRUNCATE TABLE #tmpList

  
SELECT RH1.DimReportingHierarchyKey, RH1.DivisionName, RH1.Subdivisionname, RH1.DepartmentName 
INTO #DimReportingHierarchy
FROM vReportDimReportingHierarchy RH1
JOIN vReportDimReportingHierarchy RH2 
	ON RH2.DivisionName = RH1.DivisionName
	AND RH2.subdivisionname =  RH1.subdivisionname 
	AND RH2.DepartmentName = RH1.DepartmentName 
WHERE RH2.DimReportingHierarchyKey IN (SELECT #D.DimReportingHierarchyKey FROM #Departments #D )
ORDER BY RH1.DimReportingHierarchyKey

  
SELECT P.ProductID, P.Description ProductDescription, P.PackageProductFlag, #RH.DepartmentName AS DepartmentDescription
  FROM dbo.vClub C
  JOIN #Clubs CS
       ON C.ClubID = CS.ClubID 
  JOIN dbo.vClubProduct CP
       ON C.ClubID = CP.ClubID  
  JOIN dbo.vProduct P
       ON CP.ProductID = P.ProductID
  JOIN DBO.vReportDimProduct DP
	   ON DP.MMSProductID = P.ProductID
  JOIN #DimReportingHierarchy #RH
       ON #RH.DimReportingHierarchyKey = DP.DimReportingHierarchyKey    
 WHERE C.DisplayUIFlag = 1
 GROUP BY P.ProductID, P.Description, P.PackageProductFlag, #RH.DepartmentName
 ORDER BY P.Description

DROP TABLE #Clubs
DROP TABLE #Departments
DROP TABLE #tmpList

END

