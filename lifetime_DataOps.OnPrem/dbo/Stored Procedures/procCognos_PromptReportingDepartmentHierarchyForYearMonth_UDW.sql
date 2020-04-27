



CREATE PROC [dbo].[procCognos_PromptReportingDepartmentHierarchyForYearMonth_UDW] (
 @StartFourDigitYearDashTwoDigitMonth Varchar(22),
 @EndFourDigitYearDashTwoDigitMonth Varchar(22)
 )
 AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

IF 1=0 BEGIN
   SET FMTONLY OFF
END

--- Sample Execution
-- EXEC procCognos_PromptReportingDepartmentHierarchyForYearMonth_UDW '2019-06','2019-06'
---

DECLARE @StartFourDigitYearDashTwoDigitMonth1 Varchar(22)
DECLARE @EndFourDigitYearDashTwoDigitMonth1 Varchar(22)

SELECT @StartFourDigitYearDashTwoDigitMonth1 = CASE WHEN @StartFourDigitYearDashTwoDigitMonth = 'NULL'
                                                        THEN @EndFourDigitYearDashTwoDigitMonth
                                                   WHEN @StartFourDigitYearDashTwoDigitMonth = 'Current Month'
                                                        THEN CurrentMonthDimDate.FourDigitYearDashTwoDigitMonth
                                                   WHEN @StartFourDigitYearDashTwoDigitMonth = 'Next Month'
                                                        THEN NextMonthDimDate.FourDigitYearDashTwoDigitMonth
                                                   WHEN @StartFourDigitYearDashTwoDigitMonth = 'Month After Next Month'
                                                        THEN MonthAfterNextMonthDimDate.FourDigitYearDashTwoDigitMonth
                                                   WHEN @StartFourDigitYearDashTwoDigitMonth = 'Current Quarter'
                                                        THEN Quarters.Quarter_Start
                                                   ELSE @StartFourDigitYearDashTwoDigitMonth
                                              END,
       @EndFourDigitYearDashTwoDigitMonth1 = CASE WHEN @EndFourDigitYearDashTwoDigitMonth = 'NULL'
                                                        THEN @StartFourDigitYearDashTwoDigitMonth
                                                   WHEN @EndFourDigitYearDashTwoDigitMonth = 'Current Month'
                                                        THEN CurrentMonthDimDate.FourDigitYearDashTwoDigitMonth
                                                   WHEN @EndFourDigitYearDashTwoDigitMonth = 'Next Month'
                                                        THEN NextMonthDimDate.FourDigitYearDashTwoDigitMonth
                                                   WHEN @EndFourDigitYearDashTwoDigitMonth = 'Month After Next Month'
                                                        THEN MonthAfterNextMonthDimDate.FourDigitYearDashTwoDigitMonth
                                                   WHEN @EndFourDigitYearDashTwoDigitMonth = 'Current Quarter'
                                                        THEN Quarters.Quarter_End
                                                   ELSE @EndFourDigitYearDashTwoDigitMonth 
                                              END
FROM vReportDimDate CurrentMonthDimDate
JOIN vReportDimDate NextMonthDimDate
  ON CurrentMonthDimDate.NextMonthStartingDimDateKey = NextMonthDimDate.DimDateKey
JOIN vReportDimDate MonthAfterNextMonthDimDate
  ON CurrentMonthDimDate.NextMonthStartingDimDateKey = MonthAfterNextMonthDimDate.DimDateKey
JOIN (SELECT CalendarYear,
             CalendarQuarterNumber,
             MIN(FourDigitYearDashTwoDigitMonth) Quarter_Start,
             MAX(FourDigitYearDashTwoDigitMonth) Quarter_End 
        FROM vReportDimDate 
       GROUP BY CalendarYear,
                CalendarQuarterNumber) Quarters
  ON CurrentMonthDimDate.CalendarQuarterNumber = Quarters.CalendarQuarterNumber
 And CurrentMonthDimDate.CalendarYear = Quarters.CalendarYear
WHERE CurrentMonthDimDate.CalendarDate = Convert(Datetime,Convert(Varchar,GetDate()-2,101),101)

DECLARE @StartMonthStartingDimDateKey INT,
         @EndMonthEndingDimDateKey INT 
          
SELECT @StartMonthStartingDimDateKey = MonthStartingDimDateKey
  FROM vReportDimDate
 WHERE FourDigitYearDashTwoDigitMonth = @StartFourDigitYearDashTwoDigitMonth1
   AND DayNumberInCalendarMonth = 1

SELECT @EndMonthEndingDimDateKey = MonthEndingDimDateKey
  FROM vReportDimDate 
 WHERE FourDigitYearDashTwoDigitMonth = @EndFourDigitYearDashTwoDigitMonth1
   AND LastDayInMonthIndicator = 'Y'



IF OBJECT_ID('tempdb.dbo.#DimReportingHierarchy', 'U') IS NOT NULL 
DROP TABLE #DimReportingHierarchy; 

SELECT reporting_region_type AS RegionType,
       reporting_division AS DivisionName,
       reporting_sub_division AS SubdivisionName,
       reporting_department AS DepartmentName,
       reporting_product_group AS ProductGroupName,
	   NULL as ProductGroupSortOrder,
       dim_reporting_hierarchy_key AS DimReportingHierarchyKey
  INTO #DimReportingHierarchy
  FROM vReportDimReportingHierarchyHistory_UDW
 WHERE effective_dim_date_key <= @EndMonthEndingDimDateKey
   AND expiration_dim_date_key > @StartMonthStartingDimDateKey
   AND dim_reporting_hierarchy_key > '0'

IF OBJECT_ID('tempdb.dbo.#DepartmentMinKeys', 'U') IS NOT NULL
 DROP TABLE #DepartmentMinKeys; 


SELECT 	DivisionName,
        SubdivisionName,
        DepartmentName,
        Min(DimReportingHierarchyKey) MinKey
INTO #DepartmentMinKeys
FROM #DimReportingHierarchy
GROUP BY DivisionName,
         SubDivisionName,
         DepartmentName


SELECT Distinct #DimReportingHierarchy.RegionType,
                #DimReportingHierarchy.DivisionName,
                #DimReportingHierarchy.SubdivisionName,
                #DimReportingHierarchy.DepartmentName,
                #DimReportingHierarchy.ProductGroupName,
                #DimReportingHierarchy.ProductGroupSortOrder,
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

