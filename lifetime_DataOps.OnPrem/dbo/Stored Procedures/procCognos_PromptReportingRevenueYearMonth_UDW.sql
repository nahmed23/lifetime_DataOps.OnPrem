



CREATE PROC [dbo].[procCognos_PromptReportingRevenueYearMonth_UDW] AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

IF 1=0 BEGIN
   SET FMTONLY OFF
END

--- Sample Execution
-- EXEC [dbo].[procCognos_PromptReportingRevenueYearMonth_UDW]
---

DECLARE @ThisMonthStartingDimDateKey INT,
        @NextMonthStartingDimDateKey INT,
        @LastCompletedFourDigitYearDashTwoDigitMonth CHAR(7),
        @MonthAfterNextMonthStartingDimDateKey INT

SELECT @ThisMonthStartingDimDateKey = TodayDimDate.monthstartingdimdatekey,
       @NextMonthStartingDimDateKey = TodayDimDate.nextmonthstartingdimdatekey,
       @LastCompletedFourDigitYearDashTwoDigitMonth = PriorMonthDimDate.fourdigityeardashtwodigitmonth,
       @MonthAfterNextMonthStartingDimDateKey = NextMonthDimDate.nextmonthstartingdimdatekey
  FROM [dbo].[vReportDimDate]  TodayDimDate
  JOIN [dbo].[vReportDimDate]  PriorMonthDimDate
    ON TodayDimDate.CalendarPriorMonthStartingDate = PriorMonthDimDate.CalendarDate
  JOIN [dbo].[vReportDimDate] NextMonthDimDate
    ON TodayDimDate.CalendarNextMonthStartingDate = NextMonthDimDate.CalendarDate
 WHERE TodayDimDate.calendarDate = CONVERT(Datetime,Convert(Varchar,GetDate(),101),101)

 DECLARE @YesterdayFourDigitYearDashTwoDigitMonth CHAR(7),
        @TwoDaysAgoFourDigitYearDashTwoDigitMonth CHAR(7),
		@YesterdayCalendarDate Datetime,
		@TwoDaysAgoCalendarDate Datetime
SELECT @YesterdayFourDigitYearDashTwoDigitMonth = fourdigityeardashtwodigitmonth,
       @YesterdayCalendarDate = CalendarDate 
  FROM [dbo].[vReportDimDate]
 WHERE CalendarDate = CONVERT(Datetime,Convert(Varchar,GetDate()-1,101),101)

SELECT @TwoDaysAgoFourDigitYearDashTwoDigitMonth = fourdigityeardashtwodigitmonth,
       @TwoDaysAgoCalendarDate = CalendarDate
  FROM [dbo].[vReportDimDate]
 WHERE CalendarDate = CONVERT(Datetime,Convert(Varchar,GetDate()-2,101),101)

 --select top 100 * from [dbo].[vReportDimDate] 
 --where CalendarYear = 2020

IF OBJECT_ID('tempdb.dbo.#Month2007ThroughLastMonthNextYear', 'U') IS NOT NULL
  DROP TABLE #Month2007ThroughLastMonthNextYear;

SELECT dimDateKey, 
       fourdigityeardashtwodigitmonth AS FourDigitYearDashTwoDigitMonth,
       Convert(Varchar,CalendarYear) + '-' + CalendarQuarterName AS  FourDigitYearDashCalendarQuarterName
  INTO #Month2007ThroughLastMonthNextYear
  FROM [dbo].[vReportDimDate] 
  WHERE CalendarMonthEndingDate = CalendarDate
   AND CalendarYear >= 2007
   AND CalendarYear <= year(getdate()) +1

   IF OBJECT_ID('tempdb.dbo.#Quarters', 'U') IS NOT NULL
  DROP TABLE #Quarters;

SELECT FourDigitYearDashCalendarQuarterName,
       MIN(FourDigitYearDashTwoDigitMonth) StartOfQuarterFourDigitYearDashTwoDigitMonth,
       MAX(FourDigitYearDashTwoDigitMonth) EndOfQuarterFourDigitYearDashTwoDigitMonth
  INTO #Quarters
  FROM #Month2007ThroughLastMonthNextYear
  GROUP BY FourDigitYearDashCalendarQuarterName

IF OBJECT_ID('tempdb.dbo.#Results', 'U') IS NOT NULL
  DROP TABLE #Results;

SELECT CASE WHEN DimDate.monthstartingdimdatekey = @ThisMonthStartingDimDateKey THEN 'Current Month'
            WHEN DimDate.monthstartingdimdatekey = @NextMonthStartingDimDateKey THEN 'Next Month'
            WHEN DimDate.monthstartingdimdatekey = @MonthAfterNextMonthStartingDimDateKey THEN 'Month after Next Month'
            ELSE '' END PromptDescription,
       MonthList.FourDigitYearDashTwoDigitMonth,
       MonthList.FourDigitYearDashCalendarQuarterName,
       @YesterdayCalendarDate AS YesterdayCalendarDate,
       @TwoDaysAgoCalendarDate AS TwoDaysAgoCalendarDate,
       JanuaryDimDate.fourdigityeardashtwodigitmonth AS JanuaryOfReportingYear
  INTO #Results
  FROM #Month2007ThroughLastMonthNextYear MonthList
  JOIN [dbo].[vReportDimDate]   DimDate
    ON MonthList.dimdatekey = DimDate.dimdatekey
  JOIN [dbo].[vReportDimDate] JanuaryDimDate
    ON DimDate.CalendarYear = JanuaryDimDate.CalendarYear
   AND JanuaryDimDate.CalendarMonthNumberInYear = 1
   AND JanuaryDimDate.DayNumberInCalendarMonth = 1


SELECT #Results.FourDigitYearDashTwoDigitMonth,
       #Results.FourDigitYearDashTwoDigitMonth AS ReportingFourDigitYearDashTwoDigitMonth,
       JanuaryTwoYearsPriorToYesterdayDimDate.FourDigitYearDashTwoDigitMonth AS JanuaryTwoYearsPriorToYesterday,
       @LastCompletedFourDigitYearDashTwoDigitMonth AS LastCompletedFourDigitYearDashTwoDigitMonth,
       YesterdayDimDate.FourDigitYearDashTwoDigitMonth AS YesterdayFourDigitYearDashTwoDigitMonth,
       #Results.JanuaryOfReportingYear,
       #Results.FourDigitYearDashCalendarQuarterName,
       #Quarters.StartOfQuarterFourDigitYearDashTwoDigitMonth,
       #Quarters.EndOfQuarterFourDigitYearDashTwoDigitMonth,
       4 SortOrder
  FROM #Results
  JOIN [dbo].[vReportDimDate]  YesterdayDimDate
    ON #Results.YesterdayCalendarDate = YesterdayDimDate.calendardate
  JOIN [dbo].[vReportDimDate] JanuaryTwoYearsPriorToYesterdayDimDate
    ON YesterdayDimDate.CalendarYear = JanuaryTwoYearsPriorToYesterdayDimDate.CalendarYear + 2
   AND JanuaryTwoYearsPriorToYesterdayDimDate.CalendarMonthNumberInYear = 1
   AND JanuaryTwoYearsPriorToYesterdayDimDate.DayNumberInCalendarMonth = 1
  JOIN #Quarters
    ON #Results.FourDigitYearDashTwoDigitMonth >= #Quarters.StartOfQuarterFourDigitYearDashTwoDigitMonth
   AND #Results.FourDigitYearDashTwoDigitMonth <= #Quarters.EndOfQuarterFourDigitYearDashTwoDigitMonth
 
 UNION ALL

SELECT #Results.PromptDescription AS FourDigitYearDashTwoDigitMonth,
       #Results.FourDigitYearDashTwoDigitMonth AS  ReportingFourDigitYearDashTwoDigitMonth,
       JanuaryTwoYearsPriorToYesterdayDimDate.FourDigitYearDashTwoDigitMonth AS JanuaryTwoYearsPriorToYesterday,
       @LastCompletedFourDigitYearDashTwoDigitMonth AS LastCompletedFourDigitYearDashTwoDigitMonth,
       YesterdayDimDate.FourDigitYearDashTwoDigitMonth AS YesterdayFourDigitYearDashTwoDigitMonth,
       #Results.JanuaryOfReportingYear,
       CASE WHEN #Results.FourDigitYearDashCalendarQuarterName = CONVERT(VARCHAR,YesterdayDimDate.CalendarYear) + '-' + YesterdayDimDate.CalendarQuarterName
                 THEN 'Current Quarter'
            ELSE #Results.FourDigitYearDashCalendarQuarterName END FourDigitYearDashCalendarQuarterName,
       CASE WHEN #Results.FourDigitYearDashCalendarQuarterName = CONVERT(VARCHAR,YesterdayDimDate.CalendarYear) + '-' + YesterdayDimDate.CalendarQuarterName
                 THEN 'Current Quarter'
            ELSE #Quarters.StartOfQuarterFourDigitYearDashTwoDigitMonth END StartOfQuarterFourDigitYearDashTwoDigitMonth,
       CASE WHEN #Results.FourDigitYearDashCalendarQuarterName = CONVERT(VARCHAR,YesterdayDimDate.CalendarYear) + '-' + YesterdayDimDate.CalendarQuarterName
                 THEN 'Current Quarter'
            ELSE #Quarters.EndOfQuarterFourDigitYearDashTwoDigitMonth END EndOfQuarterFourDigitYearDashTwoDigitMonth,
       1 SortOrder
  FROM #Results
  JOIN [dbo].[vReportDimDate]  YesterdayDimDate
    ON #Results.TwoDaysAgoCalendarDate = YesterdayDimDate.calendardate
  JOIN [dbo].[vReportDimDate]  JanuaryTwoYearsPriorToYesterdayDimDate
    ON YesterdayDimDate.CalendarYear = JanuaryTwoYearsPriorToYesterdayDimDate.CalendarYear + 2
   AND JanuaryTwoYearsPriorToYesterdayDimDate.CalendarMonthNumberInYear = 1
   AND JanuaryTwoYearsPriorToYesterdayDimDate.DayNumberInCalendarMonth = 1
  JOIN #Quarters
    ON #Results.FourDigitYearDashTwoDigitMonth >= #Quarters.StartOfQuarterFourDigitYearDashTwoDigitMonth
   AND #Results.FourDigitYearDashTwoDigitMonth <= #Quarters.EndOfQuarterFourDigitYearDashTwoDigitMonth
 WHERE #Results.PromptDescription = 'Current Month'    

 UNION ALL

SELECT #Results.PromptDescription AS FourDigitYearDashTwoDigitMonth,
       #Results.FourDigitYearDashTwoDigitMonth AS ReportingFourDigitYearDashTwoDigitMonth,
       JanuaryTwoYearsPriorToYesterdayDimDate.FourDigitYearDashTwoDigitMonth AS JanuaryTwoYearsPriorToYesterday,
       @LastCompletedFourDigitYearDashTwoDigitMonth AS LastCompletedFourDigitYearDashTwoDigitMonth,
       YesterdayDimDate.FourDigitYearDashTwoDigitMonth AS YesterdayFourDigitYearDashTwoDigitMonth,
       #Results.JanuaryOfReportingYear,
       CASE WHEN #Results.FourDigitYearDashCalendarQuarterName = CONVERT(VARCHAR,YesterdayDimDate.CalendarYear) + '-' + YesterdayDimDate.CalendarQuarterName
                 THEN 'Current Quarter'
            ELSE #Results.FourDigitYearDashCalendarQuarterName END FourDigitYearDashCalendarQuarterName,
       CASE WHEN #Results.FourDigitYearDashCalendarQuarterName = CONVERT(VARCHAR,YesterdayDimDate.CalendarYear) + '-' + YesterdayDimDate.CalendarQuarterName
                 THEN 'Current Quarter'
            ELSE #Quarters.StartOfQuarterFourDigitYearDashTwoDigitMonth END StartOfQuarterFourDigitYearDashTwoDigitMonth,
       CASE WHEN #Results.FourDigitYearDashCalendarQuarterName = CONVERT(VARCHAR,YesterdayDimDate.CalendarYear) + '-' + YesterdayDimDate.CalendarQuarterName
                 THEN 'Current Quarter'
            ELSE #Quarters.EndOfQuarterFourDigitYearDashTwoDigitMonth END EndOfQuarterFourDigitYearDashTwoDigitMonth,
       2 SortOrder
  FROM #Results
  JOIN [dbo].[vReportDimDate] YesterdayDimDate
    ON #Results.YesterdayCalendarDate = YesterdayDimDate.calendardate
  JOIN [dbo].[vReportDimDate] JanuaryTwoYearsPriorToYesterdayDimDate
    ON YesterdayDimDate.CalendarYear = JanuaryTwoYearsPriorToYesterdayDimDate.CalendarYear + 2
   AND JanuaryTwoYearsPriorToYesterdayDimDate.CalendarMonthNumberInYear = 1
   AND JanuaryTwoYearsPriorToYesterdayDimDate.DayNumberInCalendarMonth = 1 
  JOIN #Quarters
    ON #Results.FourDigitYearDashTwoDigitMonth >= #Quarters.StartOfQuarterFourDigitYearDashTwoDigitMonth
   AND #Results.FourDigitYearDashTwoDigitMonth <= #Quarters.EndOfQuarterFourDigitYearDashTwoDigitMonth
 WHERE #Results.PromptDescription = 'Next Month'

 UNION ALL

SELECT #Results.PromptDescription AS FourDigitYearDashTwoDigitMonth,
       #Results.FourDigitYearDashTwoDigitMonth AS ReportingFourDigitYearDashTwoDigitMonth,
       JanuaryTwoYearsPriorToYesterdayDimDate.FourDigitYearDashTwoDigitMonth AS JanuaryTwoYearsPriorToYesterday,
       @LastCompletedFourDigitYearDashTwoDigitMonth AS LastCompletedFourDigitYearDashTwoDigitMonth,
       YesterdayDimDate.FourDigitYearDashTwoDigitMonth AS YesterdayFourDigitYearDashTwoDigitMonth,
       #Results.JanuaryOfReportingYear,
       CASE WHEN #Results.FourDigitYearDashCalendarQuarterName = CONVERT(VARCHAR,YesterdayDimDate.CalendarYear) + '-' + YesterdayDimDate.CalendarQuarterName
                 THEN 'Current Quarter'
            ELSE #Results.FourDigitYearDashCalendarQuarterName END FourDigitYearDashCalendarQuarterName,
       CASE WHEN #Results.FourDigitYearDashCalendarQuarterName = CONVERT(VARCHAR,YesterdayDimDate.CalendarYear) + '-' + YesterdayDimDate.CalendarQuarterName
                 THEN 'Current Quarter'
            ELSE #Quarters.StartOfQuarterFourDigitYearDashTwoDigitMonth END StartOfQuarterFourDigitYearDashTwoDigitMonth,
       CASE WHEN #Results.FourDigitYearDashCalendarQuarterName = CONVERT(VARCHAR,YesterdayDimDate.CalendarYear) + '-' + YesterdayDimDate.CalendarQuarterName
                 THEN 'Current Quarter'
            ELSE #Quarters.EndOfQuarterFourDigitYearDashTwoDigitMonth END EndOfQuarterFourDigitYearDashTwoDigitMonth,
       3 SortOrder
  FROM #Results
  JOIN [dbo].[vReportDimDate]  YesterdayDimDate
    ON #Results.YesterdayCalendarDate = YesterdayDimDate.calendardate
  JOIN [dbo].[vReportDimDate] JanuaryTwoYearsPriorToYesterdayDimDate
    ON YesterdayDimDate.CalendarYear = JanuaryTwoYearsPriorToYesterdayDimDate.CalendarYear + 2
   AND JanuaryTwoYearsPriorToYesterdayDimDate.CalendarMonthNumberInYear = 1
   AND JanuaryTwoYearsPriorToYesterdayDimDate.DayNumberInCalendarMonth = 1 
  JOIN #Quarters
    ON #Results.FourDigitYearDashTwoDigitMonth >= #Quarters.StartOfQuarterFourDigitYearDashTwoDigitMonth
   AND #Results.FourDigitYearDashTwoDigitMonth <= #Quarters.EndOfQuarterFourDigitYearDashTwoDigitMonth
 WHERE #Results.PromptDescription = 'Month after Next Month'
 ORDER BY SortOrder, FourDigitYearDashTwoDigitMonth DESC

 DROP TABLE #Results


END
