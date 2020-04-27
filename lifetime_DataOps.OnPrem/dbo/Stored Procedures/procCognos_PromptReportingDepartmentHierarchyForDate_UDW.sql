


CREATE PROC [dbo].[procCognos_PromptReportingDepartmentHierarchyForDate_UDW] (
   @StartDate DateTime,
   @EndDate DateTime
)
AS
BEGIN 
SET XACT_ABORT ON
SET NOCOUNT ON

IF 1=0 BEGIN
       SET FMTONLY OFF
     END

  ----- Sample Execution
  -----  EXEC procCognos_PromptReportingDepartmentHierarchyForDate_UDW  '1/1/2019','1/10/2019'
  -----

DECLARE @StartCalendarDateDimDateKey INT,
        @EndCalendarDateDimDateKey INT

SELECT @StartCalendarDateDimDateKey = CASE WHEN @StartDate = '1/2/1900' 
                                  THEN (SELECT DimDateKey FROM vReportDimDate WHERE CalendarDate = @EndDate)
                                 WHEN @StartDate = '1/1/1900' 
								  THEN (SELECT MonthStartingDimDateKey FROM vReportDimDate Where CalendarDate = @EndDate)
                                 ELSE (SELECT DimDateKey FROM vReportDimDate WHERE CalendarDate = @StartDate)
								 END
SELECT @EndCalendarDateDimDateKey = CASE WHEN @EndDate = '1/2/1900'  
	                                       THEN (SELECT DimDateKey FROM vReportDimDate WHERE CalendarDate = @StartDate)
                                         WHEN @EndDate = '1/1/1900' 
							               THEN (SELECT DimDateKey FROM vReportDimDate WHERE CalendarDate = CONVERT(Datetime,Convert(Varchar,GetDate()-1,101),101))
                                         ELSE (SELECT DimDateKey FROM vReportDimDate WHERE CalendarDate = @EndDate) 
							             END

  IF OBJECT_ID('tempdb.dbo.#DimReportingHierarchy', 'U') IS NOT NULL
  DROP TABLE #DimReportingHierarchy; 

SELECT reporting_region_type AS RegionType,
       reporting_division AS DivisionName,
       reporting_sub_division AS SubdivisionName,
       reporting_department AS DepartmentName,
       reporting_product_group AS ProductGroupName,
       -----ProductGroupSortOrder,
       dim_reporting_hierarchy_key AS DimReportingHierarchyKey
  INTO #DimReportingHierarchy
  FROM [dbo].[vReportDimReportingHierarchyHistory_UDW]
 WHERE effective_dim_date_key <= @EndCalendarDateDimDateKey 
   AND expiration_dim_date_key > @StartCalendarDateDimDateKey 
   AND dim_reporting_hierarchy_key not in('-997','-998','-999')


  IF OBJECT_ID('tempdb.dbo.#DepartmentMinKeys', 'U') IS NOT NULL
  DROP TABLE #DepartmentMinKeys;
    
SELECT DivisionName,
       SubdivisionName,
       DepartmentName,
       MIN(DimReportingHierarchyKey) MinKey
  INTO #DepartmentMinKeys
  FROM #DimReportingHierarchy
 GROUP BY DivisionName,
          SubdivisionName,
          DepartmentName

SELECT #DimReportingHierarchy.RegionType,
       #DimReportingHierarchy.DivisionName,
       #DimReportingHierarchy.SubdivisionName,
       #DimReportingHierarchy.DepartmentName,
       #DimReportingHierarchy.ProductGroupName,
       -------#DimReportingHierarchy.ProductGroupSortOrder,
       #DimReportingHierarchy.DimReportingHierarchyKey,
       Cast(#DepartmentMinKeys.MinKey as Varchar(32)) DepartmentMinDimReportingHierarchyKey
  FROM #DimReportingHierarchy
  JOIN #DepartmentMinKeys
    ON #DimReportingHierarchy.DivisionName = #DepartmentMinKeys.DivisionName
   AND #DimReportingHierarchy.SubdivisionName = #DepartmentMinKeys.SubdivisionName
   AND #DimReportingHierarchy.DepartmentName = #DepartmentMinKeys.DepartmentName

DROP TABLE #DimReportingHierarchy
DROP TABLE #DepartmentMinKeys


END



