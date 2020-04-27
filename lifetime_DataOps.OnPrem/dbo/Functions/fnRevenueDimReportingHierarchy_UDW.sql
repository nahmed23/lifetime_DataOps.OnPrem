
CREATE FUNCTION [dbo].[fnRevenueDimReportingHierarchy_UDW] (
@DivisionList VARCHAR(8000),
@SubdivisionList VARCHAR(8000),
@DepartmentMinDimReportingHierarchyKeyList VARCHAR(8000),
@DimReportingHierarchyKeyList VARCHAR(8000),
@StartMonthStartingDimDateKey INT,
@EndMonthEndingDimDateKey INT
)

RETURNS @OutputTable TABLE (
DimReportingHierarchyKey VARCHAR(32),
DepartmentMinDimReportingHierarchyKey VARCHAR(32),
DivisionName VARCHAR(255),
SubdivisionName VARCHAR(255),
DepartmentName VARCHAR(255),
ProductGroupName VARCHAR(255),
-----ProductGroupSortOrder INT,
RegionType VARCHAR(50),
HeaderDivisionList VARCHAR(8000),
HeaderSubdivisionList VARCHAR(8000),
HeaderDepartmentList VARCHAR(8000),
HeaderProductGroupList VARCHAR(8000),
ReportRegionType VARCHAR(50)
)

AS
BEGIN

SET @DivisionList = CASE WHEN @DivisionList = 'N/A' Then 'All Divisions' Else @DivisionList END
SET @SubdivisionList = Case When @SubdivisionList = 'N/A' Then 'All Subdivisions' Else @SubdivisionList END
SET @DepartmentMinDimReportingHierarchyKeyList = CASE When @DepartmentMinDimReportingHierarchyKeyList = 'N/A' Then 'All Departments' Else @DepartmentMinDimReportingHierarchyKeyList END
SET @DimReportingHierarchyKeyList = Case When @DimReportingHierarchyKeyList= 'N/A' Then 'All Product Groups' Else @DimReportingHierarchyKeyList  END

INSERT INTO @OutputTable
SELECT DISTINCT DimReportingHierarchy.dim_reporting_hierarchy_key AS DimReportingHierarchyKey,
       Null as DepartmentMinDimReportingHierarchyKey,
       DimReportingHierarchy.reporting_division AS DivisionName,
       DimReportingHierarchy.reporting_sub_division AS SubdivisionName,
       DimReportingHierarchy.reporting_department AS DepartmentName,
       DimReportingHierarchy.reporting_product_group AS ProductGroupName,
       -----DimReportingHierarchy.ProductGroupSortOrder,
       DimReportingHierarchy.reporting_region_type AS RegionType,
       '' as HeaderDivisionList,
       '' as HeaderSubdivisionList,
       '' as HeaderDepartmentList,
       '' as HeaderProductGroupList,
       DepartmentTable.ReportRegionType
  FROM fnRevenueDepartmentDimReportingHierarchy_UDW(@DivisionList, @SubdivisionList, @DepartmentMinDimReportingHierarchyKeyList,@StartMonthStartingDimDateKey, @EndMonthEndingDimDateKey) DepartmentTable
  JOIN vReportDimReportingHierarchyHistory_UDW AS DimReportingHierarchy
    On DepartmentTable.DivisionName = DimReportingHierarchy.reporting_division
   AND DepartmentTable.SubdivisionName = DimReportingHierarchy.reporting_sub_division
   AND DepartmentTable.DepartmentName = DimReportingHierarchy.reporting_department
  JOIN fnParsePipeList(@DimReportingHierarchyKeyList) AS ProductGroupKeyList
    On Cast(DimReportingHierarchy.dim_reporting_hierarchy_key as Varchar) = ProductGroupKeyList.Item
    Or ProductGroupKeyList.Item = 'All Product Groups'
  JOIN (SELECT MAX(MonthEndingDimDateKey) MonthEndingDimDateKey
                        FROM vReportDimDate
                       WHERE DimDateKey >= @StartMonthStartingDimDateKey
                         AND DimDateKey <= @EndMonthEndingDimDateKey) AS MonthEndingDimDateKeys
    On DimReportingHierarchy.effective_dim_date_key <= MonthEndingDimDateKeys.MonthEndingDimDateKey
   AND DimReportingHierarchy.expiration_dim_date_key > MonthEndingDimDateKeys.MonthEndingDimDateKey
 WHERE DimReportingHierarchy.dim_reporting_hierarchy_key not in ('-997','-998','-999')
   AND DimReportingHierarchy.reporting_product_group <> ''

UPDATE OuterOutputTable
   SET HeaderDivisionList = STUFF((SELECT DISTINCT ','+DivisionName
                                     FROM @OutputTable
                                      FOR XML PATH(''),ROOT('Divisions'),type).value('/Divisions[1]','varchar(8000)'),1,1,''),
       HeaderSubdivisionList = STUFF((SELECT DISTINCT ','+SubdivisionName
                                        FROM @OutputTable
                                         FOR XML PATH(''),ROOT('Subdivisions'),type).value('/Subdivisions[1]','varchar(8000)'),1,1,''),
       HeaderDepartmentList = STUFF((SELECT DISTINCT ','+DepartmentName
                                       FROM @OutputTable
                                        FOR XML PATH(''),ROOT('Departments'),type).value('/Departments[1]','varchar(8000)'),1,1,''),
       HeaderProductGroupList = STUFF((SELECT DISTINCT ','+ProductGroupName
                                         FROM @OutputTable
                                          FOR XML PATH(''),ROOT('ProductGroups'),type).value('/ProductGroups[1]','varchar(8000)'),1,1,''),
       DepartmentMinDimReportingHierarchyKey = (SELECT MIN(DimReportingHierarchyKey)
                                                  FROM @OutputTable InnerOutputTable
                                                 WHERE OuterOutputTable.DivisionName = InnerOutputTable.DivisionName
                                                   AND OuterOutputTable.SubdivisionName = InnerOutputTable.SubdivisionName
                                                   AND OuterOutputTable.DepartmentName = InnerOutputTable.DepartmentName
                                                 GROUP BY DivisionName, SubdivisionName, DepartmentName)
  FROM @OutputTable OuterOutputTable

RETURN

END


