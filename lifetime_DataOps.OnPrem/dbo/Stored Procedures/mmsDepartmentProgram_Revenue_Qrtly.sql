

CREATE PROC [dbo].[mmsDepartmentProgram_Revenue_Qrtly](
	@Year INT,
    @Department VARCHAR(2000), --RevenueReportingDepartment
	@Programs VARCHAR(2000),
	@Quarters VARCHAR(10)
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON


--	============================================================================
--	Object:			dbo.mmsDepartmentProgram_Revenue_Qrtly
--	Author:			Greg Burdick
--	Create Date:	4/20/2009 deploying 4/29/2009 via dbcr_4457
--	Description:	Returns revenue totals for specified year, department, and quarter(s) 
--	Modified:		5/21/2009 GRB: added 'All' option for programs to FROM clause; deploying dbcr_4588 on 6/03/2009
--                  1/31/2011 BSD: @Department now accepts RevenueReportingDepartments
--
--	EXEC mmsDepartmentProgram_Revenue_Qrtly 2009,'Member Activities', 'Youth Fitness|Camps|Birthday Parties|Dance - Martial Arts|Basketball|Squash - Racquetball|Rock Climbing|Events - Other', '1|2|3'
--	EXEC mmsDepartmentProgram_Revenue_Qrtly 2009,'Tennis', 'Court Time|Drills|Jr. Programs|Leagues|Lessons|Miscellaneous|Pro Shop', '3|4'
--	EXEC mmsDepartmentProgram_Revenue_Qrtly 2009,'Aquatics', 'Group Lessons|Private Lessons|Swim Team|Masters|Events|Other', '2|4'
-- ===========================================================================

-- Report Logging
DECLARE @Identity AS INT
INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
SET @Identity = @@IDENTITY

CREATE TABLE #tmpList (StringField VARCHAR(200))

--	Programs
CREATE TABLE #tmpPrograms(ProgramDescription VARCHAR(30))
EXEC procParseStringList @Programs
INSERT INTO #tmpPrograms (ProgramDescription) SELECT StringField FROM #tmpList
TRUNCATE TABLE #tmpList

--	Quarter
CREATE TABLE #tmpQuarters(QuarterID VARCHAR(1))
EXEC procParseStringList @Quarters
INSERT INTO #tmpQuarters(QuarterID) SELECT StringField FROM #tmpList
TRUNCATE TABLE #tmpList

--  Departments
CREATE TABLE #Departments (Department VARCHAR(50))
EXEC procParseStringList @Department
INSERT INTO #Departments (Department) SELECT StringField FROM #tmpList --RevenueReportingDepartment



	SELECT 
		VMAR.Description AS PostingRegionDescription, C.ClubID AS PostingClubID, C.ClubName AS PostingClubName,
		C.ClubCode [PostingClubCode], --'Member Activities',
		vpg.RevenueReportingDepartment [Department], --1/31/2011 BSD
		LEFT(GLRevenueMonth, 4) [RevenueYear], 
		CASE	WHEN CONVERT(INT, RIGHT(RTRIM(GLRevenueMonth), 2)) BETWEEN 1 AND 3 THEN '1'
				WHEN CONVERT(INT, RIGHT(RTRIM(GLRevenueMonth), 2)) BETWEEN 4 AND 6 THEN '2'
				WHEN CONVERT(INT, RIGHT(RTRIM(GLRevenueMonth), 2)) BETWEEN 7 AND 9 THEN '3'
				WHEN CONVERT(INT, RIGHT(RTRIM(GLRevenueMonth), 2)) BETWEEN 10 AND 12 THEN '4'
				ELSE '0'
		END Quarter, 
		CASE	WHEN CONVERT(INT, RIGHT(RTRIM(GLRevenueMonth), 2)) BETWEEN 1 AND 3 THEN  '1st Quarter'
				WHEN CONVERT(INT, RIGHT(RTRIM(GLRevenueMonth), 2)) BETWEEN 4 AND 6 THEN  '2nd Quarter'
				WHEN CONVERT(INT, RIGHT(RTRIM(GLRevenueMonth), 2)) BETWEEN 7 AND 9 THEN  '3rd Quarter'
				WHEN CONVERT(INT, RIGHT(RTRIM(GLRevenueMonth), 2)) BETWEEN 10 AND 12 THEN  '4th Quarter'
				ELSE 'error: quarter calculation'
		END QuarterDesc, RIGHT(RTRIM(GLRevenueMonth), 2) [RevenueMonth],
		DATENAME(MONTH, CONVERT(DATETIME, LEFT(GLRevenueMonth, 4) + '/' + RIGHT(RTRIM(GLRevenueMonth), 2) + '/01', 120)) [RevenueMonthName],	-- RevenueMonthName literal, 
		LEFT(GLRevenueMonth, 4) +	RIGHT(RTRIM(GLRevenueMonth), 2) [RevenueYearMonth], 
		vpg.Description [Program], 
		SUM(DRAS.RevenueMonthAllocation) [MonthsRevenue], 
		DRAS.TransactionType AS TranTypeDescription,
		vpg.Description + '-' + RTRIM(GLRevenueMonth) + '-' + CONVERT(VARCHAR, C.ClubID) [ProgramRevenueYearMonthClubID],
		GetDate()-1 [ReportQueryDate]

	FROM vDeferredRevenueAllocationSummary DRAS
		JOIN #tmpQuarters q ON DATEPART(q, CONVERT(DATETIME, LEFT(GLRevenueMonth, 4) + '/' + RIGHT(RTRIM(GLRevenueMonth), 2) + '/01', 120)) = q.QuarterID
		JOIN vCLUB C ON DRAS.MMSClubID=C.ClubID
		JOIN vProduct P ON DRAS.ProductID=P.ProductID
		JOIN vProductGroup pg ON DRAS.ProductID = pg.ProductID
		JOIN vValProductGroup vpg ON pg.ValProductGroupID = vpg.ValProductGroupID
		JOIN #tmpPrograms tp ON vpg.Description = tp.ProgramDescription
		LEFT JOIN vValMemberActivityRegion VMAR ON VMAR.ValMemberActivityRegionID = C.ValMemberActivityRegionID
        JOIN #Departments #D ON vpg.RevenueReportingDepartment = #D.Department   --1/31/2011 BSD
	WHERE LEFT(GLRevenueMonth, 4) = @Year
	GROUP BY
		VMAR.Description, C.ClubID, C.ClubName,
		C.ClubCode, vpg.RevenueReportingDepartment,   --1/31/2011 BSD
		LEFT(GLRevenueMonth, 4), 
		CASE	WHEN CONVERT(INT, RIGHT(RTRIM(GLRevenueMonth), 2)) BETWEEN 1 AND 3 THEN '1'
				WHEN CONVERT(INT, RIGHT(RTRIM(GLRevenueMonth), 2)) BETWEEN 4 AND 6 THEN '2'
				WHEN CONVERT(INT, RIGHT(RTRIM(GLRevenueMonth), 2)) BETWEEN 7 AND 9 THEN '3'
				WHEN CONVERT(INT, RIGHT(RTRIM(GLRevenueMonth), 2)) BETWEEN 10 AND 12 THEN '4'
				ELSE '0'
		END, 
		CASE	WHEN CONVERT(INT, RIGHT(RTRIM(GLRevenueMonth), 2)) BETWEEN 1 AND 3 THEN  '1st Quarter'
				WHEN CONVERT(INT, RIGHT(RTRIM(GLRevenueMonth), 2)) BETWEEN 4 AND 6 THEN  '2nd Quarter'
				WHEN CONVERT(INT, RIGHT(RTRIM(GLRevenueMonth), 2)) BETWEEN 7 AND 9 THEN  '3rd Quarter'
				WHEN CONVERT(INT, RIGHT(RTRIM(GLRevenueMonth), 2)) BETWEEN 10 AND 12 THEN  '4th Quarter'
				ELSE 'error: quarter calculation'
		END, RIGHT(RTRIM(GLRevenueMonth), 2),
		DATENAME(MONTH, CONVERT(DATETIME, LEFT(GLRevenueMonth, 4) + '/' + RIGHT(RTRIM(GLRevenueMonth), 2) + '/01', 120)), 
		LEFT(GLRevenueMonth, 4) +	RIGHT(RTRIM(GLRevenueMonth), 2), 
		vpg.Description, 
		DRAS.TransactionType,
		vpg.Description + '-' + RTRIM(GLRevenueMonth) + '-' + CONVERT(VARCHAR, C.ClubID)--,


DROP TABLE #tmpList

 -- Report Logging
UPDATE HyperionReportLog
SET EndDateTime = getdate()
WHERE ReportLogID = @Identity

END
