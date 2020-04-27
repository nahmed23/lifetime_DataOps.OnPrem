
-- =============================================
-- Object:			dbo.mmsDeferredNonDeferredRevenue_Historical
-- Author:			Greg Burdick
-- Create date: 	8/15/2008
-- Description:		returns product (activity) revenue, summarized by Club and Current / Previous month grouping
-- Parameters:		a list of club names, 
-- Modified date:	
-- Release date:	8/20/2008 dbcr_3450
-- Exec mmsDeferredNonDeferredRevenue_Historical 'All'
-- =============================================

CREATE  PROC [dbo].[mmsDeferredNonDeferredRevenue_Historical] (
	@ClubIDList VARCHAR(2000)
)

AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

CREATE TABLE #tmpList (StringField VARCHAR(15))
CREATE TABLE #Clubs (ClubID VARCHAR(15))

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

IF @ClubIDList <> 'All'
BEGIN
	EXEC dbo.procParseStringList @ClubIDList --inserts ClubIds into #tmpList
    INSERT INTO #Clubs (ClubID) SELECT StringField FROM #tmpList
    TRUNCATE TABLE #tmpList
END
ELSE
BEGIN
	INSERT INTO #Clubs select clubid from vclub
END

SELECT vvr.Description RegionDesc, MMSClubID, vc.ClubCode, vc.ClubName, 
	d.DepartmentID, d.Name DeptName, d.Description DeptDesc,
	CASE 
		WHEN GLAccountNumber BETWEEN 2000 AND 2999 THEN 'Deferred'
		WHEN GLAccountNumber BETWEEN 4000 AND 4999 THEN 'Non-Deferred'
		ELSE 'Other'
	END DeferredRevenueStatus, 
	CASE 
		WHEN MMSPostMonth = GLRevenueMonth THEN 'Current'
		ELSE 'Prior'
	END RevenueAllocatedMonth, 
	maras.ProductID, vp.Name ProductName, vp.Description ProductDesc, GLRevenueMonth, 
	SUBSTRING(GLRevenueMonth, 1, 4) GLRevYearPart,
	SUBSTRING(GLRevenueMonth, 5, 2) GLRevMonthPart,
	SUM(RevenueMonthAllocation) Revenue
FROM MemberActivitiesRevenueAllocationSummary maras
	JOIN vClub vc ON maras.MMSClubID = vc.ClubID
	JOIN #Clubs CS ON vc.ClubID = CS.ClubID
	JOIN vValRegion vvr ON vc.ValRegionID = vvr.ValRegionID
	JOIN vProduct vp ON maras.ProductID = vp.ProductID
	JOIN dbo.vDepartment d ON vp.DepartmentID = d.DepartmentID
WHERE GLRevenueMonth <= '200807'
GROUP BY vvr.Description,MMSClubID, vc.ClubCode, vc.ClubName, 
	d.DepartmentID, d.Name, d.Description,
	CASE 
		WHEN GLAccountNumber BETWEEN 2000 AND 2999 THEN 'Deferred'
		WHEN GLAccountNumber BETWEEN 4000 AND 4999 THEN 'Non-Deferred'
		ELSE 'Other'
	END, 
	CASE 
		WHEN MMSPostMonth = GLRevenueMonth THEN 'Current'
		ELSE 'Prior'
	END,  
	maras.ProductID, vp.Name, vp.Description, GLRevenueMonth,
	SUBSTRING(GLRevenueMonth, 1, 4),
	SUBSTRING(GLRevenueMonth, 5, 2)
ORDER BY GLRevenueMonth DESC, vvr.Description, vc.ClubName, vp.Description 

END
