

CREATE FUNCTION [dbo].[fnRevenueDepartmentDimReportingHierarchy] (
@DivisionList VARCHAR(8000),
@SubdivisionList VARCHAR(8000),
@DepartmentMinDimReportingHierarchyKeyList VARCHAR(8000),
@StartMonthStartingDimDateKey INT,
@EndMonthEndingDimDateKey INT
)

RETURNS @OutputTable TABLE (
DivisionName VARCHAR(255),
SubdivisionName VARCHAR(255),
DepartmentName VARCHAR(255),
RegionType VARCHAR(50),
ReportRegionType VARCHAR(50)
)

AS
BEGIN

INSERT INTO @OutputTable
SELECT DISTINCT 
       DimReportingHierarchy.DivisionName,
       DimReportingHierarchy.SubdivisionName,
       DimReportingHierarchy.DepartmentName,
       DimReportingHierarchy.RegionType,
       '' as ReportRegionType
  FROM vReportDimReportingHierarchy DimReportingHierarchy
  JOIN fnParsePipeList(@DivisionList) AS DivisionList
    On DimReportingHierarchy.DivisionName = DivisionList.Item
    Or DivisionList.Item = 'All Divisions'
  JOIN fnParsePipeList(@SubdivisionList) AS SubdivisionList
    On DimReportingHierarchy.SubdivisionName = SubdivisionList.Item
    Or SubdivisionList.Item = 'All Subdivisions'
  JOIN fnParsePipeList(@DepartmentMinDimReportingHierarchyKeyList) AS DepartmentMinKeyList
    On Cast(DimReportingHierarchy.DimReportingHierarchyKey as Varchar) = DepartmentMinKeyList.Item
    Or DepartmentMinKeyList.Item = 'All Departments'
  JOIN (SELECT MAX( MonthEndingDimDateKey)  MonthEndingDimDateKey
          FROM vReportDimDate
         WHERE DimDateKey >= @StartMonthStartingDimDateKey
           AND DimDateKey <= @EndMonthEndingDimDateKey) AS MonthEndKeys
    On DimReportingHierarchy.EffectiveDimDateKey <= MonthEndKeys.MonthEndingDimDateKey
   AND DimReportingHierarchy.ExpirationDimDateKey > MonthEndKeys.MonthEndingDimDateKey
 WHERE DimReportingHierarchy.DimReportingHierarchyKey > 3
   AND DimReportingHierarchy.ProductGroupName <> ''

UPDATE OuterOutputTable
   SET ReportRegionType = (SELECT CASE WHEN COUNT(DISTINCT RegionType) = 1 THEN MIN(RegionType) ELSE 'MMS Region' END FROM @OutputTable)
  FROM @OutputTable OuterOutputTable

RETURN

END


