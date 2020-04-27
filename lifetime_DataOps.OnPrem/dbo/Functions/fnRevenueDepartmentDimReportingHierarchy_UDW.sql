

CREATE FUNCTION [dbo].[fnRevenueDepartmentDimReportingHierarchy_UDW] (
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
       DimReportingHierarchy.reporting_division AS DivisionName,
       DimReportingHierarchy.reporting_sub_division AS SubdivisionName,
       DimReportingHierarchy.reporting_department AS DepartmentName,
       DimReportingHierarchy.reporting_region_type AS RegionType,
       '' as ReportRegionType
  FROM vReportDimReportingHierarchyHistory_UDW DimReportingHierarchy
  JOIN fnParsePipeList(@DivisionList) AS DivisionList
    On DimReportingHierarchy.reporting_division = DivisionList.Item
    Or DivisionList.Item = 'All Divisions'
  JOIN fnParsePipeList(@SubdivisionList) AS SubdivisionList
    On DimReportingHierarchy.reporting_sub_division = SubdivisionList.Item
    Or SubdivisionList.Item = 'All Subdivisions'
  JOIN fnParsePipeList(@DepartmentMinDimReportingHierarchyKeyList) AS DepartmentMinKeyList
    On Cast(DimReportingHierarchy.dim_reporting_hierarchy_key as Varchar) = DepartmentMinKeyList.Item
    Or DepartmentMinKeyList.Item = 'All Departments'
  JOIN (SELECT MAX( MonthEndingDimDateKey)  MonthEndingDimDateKey
          FROM vReportDimDate
         WHERE DimDateKey >= @StartMonthStartingDimDateKey
           AND DimDateKey <= @EndMonthEndingDimDateKey) AS MonthEndKeys
    On DimReportingHierarchy.effective_dim_date_key <= MonthEndKeys.MonthEndingDimDateKey
   AND DimReportingHierarchy.expiration_dim_date_key > MonthEndKeys.MonthEndingDimDateKey
 WHERE DimReportingHierarchy.dim_reporting_hierarchy_key not in ('-997','-998','-999')
   AND DimReportingHierarchy.reporting_product_group <> ''

UPDATE OuterOutputTable
   SET ReportRegionType = (SELECT CASE WHEN COUNT(DISTINCT RegionType) = 1 THEN MIN(RegionType) ELSE 'MMS Region' END FROM @OutputTable)
  FROM @OutputTable OuterOutputTable

RETURN

END




