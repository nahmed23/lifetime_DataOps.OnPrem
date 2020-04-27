

CREATE FUNCTION [dbo].[fnRevenueDimReportingHierarchy] (
@DivisionList VARCHAR(8000),
@SubdivisionList VARCHAR(8000),
@DepartmentMinDimReportingHierarchyKeyList VARCHAR(8000),
@DimReportingHierarchyKeyList VARCHAR(8000),
@StartMonthStartingDimDateKey INT,
@EndMonthEndingDimDateKey INT
)

RETURNS @OutputTable TABLE (
DimReportingHierarchyKey INT,
DepartmentMinDimReportingHierarchyKey INT,
DivisionName VARCHAR(255),
SubdivisionName VARCHAR(255),
DepartmentName VARCHAR(255),
ProductGroupName VARCHAR(255),
ProductGroupSortOrder INT,
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
SELECT DISTINCT DimReportingHierarchy.DimReportingHierarchyKey,
       Null as DepartmentMinDimReportingHierarchyKey,
       DimReportingHierarchy.DivisionName,
       DimReportingHierarchy.SubdivisionName,
       DimReportingHierarchy.DepartmentName,
       DimReportingHierarchy.ProductGroupName,
       DimReportingHierarchy.ProductGroupSortOrder,
       DimReportingHierarchy.RegionType,
       '' as HeaderDivisionList,
       '' as HeaderSubdivisionList,
       '' as HeaderDepartmentList,
       '' as HeaderProductGroupList,
       DepartmentTable.ReportRegionType
  FROM fnRevenueDepartmentDimReportingHierarchy(@DivisionList, @SubdivisionList, @DepartmentMinDimReportingHierarchyKeyList,@StartMonthStartingDimDateKey, @EndMonthEndingDimDateKey) DepartmentTable
  JOIN vReportDimReportingHierarchy AS DimReportingHierarchy
    On DepartmentTable.DivisionName = DimReportingHierarchy.DivisionName
   AND DepartmentTable.SubdivisionName = DimReportingHierarchy.SubdivisionName
   AND DepartmentTable.DepartmentName = DimReportingHierarchy.DepartmentName
  JOIN fnParsePipeList(@DimReportingHierarchyKeyList) AS ProductGroupKeyList
    On Cast(DimReportingHierarchy.DimReportingHierarchyKey as Varchar) = ProductGroupKeyList.Item
    Or ProductGroupKeyList.Item = 'All Product Groups'
  JOIN (SELECT MAX(MonthEndingDimDateKey) MonthEndingDimDateKey
                        FROM vReportDimDate
                       WHERE DimDateKey >= @StartMonthStartingDimDateKey
                         AND DimDateKey <= @EndMonthEndingDimDateKey) AS MonthEndingDimDateKeys
    On DimReportingHierarchy.EffectiveDimDateKey <= MonthEndingDimDateKeys.MonthEndingDimDateKey
   AND DimReportingHierarchy.ExpirationDimDateKey > MonthEndingDimDateKeys.MonthEndingDimDateKey
 WHERE DimReportingHierarchy.DimReportingHierarchyKey > 3
   AND DimReportingHierarchy.ProductGroupName <> ''

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


