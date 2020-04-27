
-------------------------------------------------------------------------------------------------------8
-- ==============================================================================================================
-- Object:			dbo.mmsDeferredNonDeferredRevenue
-- Author:			Greg Burdick
-- Create date: 	8/8/2008
-- Description:		returns product (activity) revenue, summarized by Club and Deferred / Non-Deferred grouping
-- Parameters:		a list of club names, 
-- Modified date:	9/17/08 by Susan Myrick to point to new summary table 
--                  1/24/2011 BSD: added RevenueReportingDepartment
-- Release date:	8/13/2008 dbcr_3476a
-- 
-- Exec mmsDeferredNonDeferredRevenue '189|151',2008,9
-- ================================================================================================================

CREATE  PROC [dbo].[mmsDeferredNonDeferredRevenue] (
	@ClubIDList VARCHAR(2000),
	@year INT,
	@month INT
)

AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

CREATE TABLE #tmpList (StringField VARCHAR(50))
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
	INSERT INTO #Clubs (ClubID) select clubid from vclub
END


SELECT vvr.Description RegionDesc, dras.MMSClubID, vc.ClubCode, vc.ClubName, 
	d.DepartmentID, d.Name DeptName, d.Description DeptDesc,
	CASE 
		WHEN vp.GLAccountNumber BETWEEN 2000 AND 2999 THEN 'Deferred'
		WHEN vp.GLAccountNumber BETWEEN 4000 AND 4999 THEN 'Non-Deferred'
		ELSE 'Other'
	END DeferredRevenueStatus, 
	CASE 
		WHEN dras.MMSPostMonth = dras.GLRevenueMonth THEN 'Current'
		ELSE 'Prior'
	END RevenueAllocatedMonth, 
	dras.ProductID, vp.Name ProductName, vp.Description ProductDesc, dras.GLRevenueMonth, 
	SUBSTRING(dras.GLRevenueMonth, 1, 4) GLRevYearPart,
	SUBSTRING(dras.GLRevenueMonth, 5, 2) GLRevMonthPart,
	SUM(dras.RevenueMonthAllocation) Revenue,
    VPG.RevenueReportingDepartment-- 1/24/2011 BSD
FROM  vDeferredRevenueAllocationSummary  dras
	JOIN vClub vc ON dras.MMSClubID = vc.ClubID
	JOIN #Clubs CS ON vc.ClubID = CS.ClubID
	JOIN vValRegion vvr ON vc.ValRegionID = vvr.ValRegionID
	JOIN vProduct vp ON dras.ProductID = vp.ProductID
	JOIN vDepartment d ON vp.DepartmentID = d.DepartmentID
    JOIN vProductGroup PG ON vp.ProductID = PG.ProductID     -- 1/24/2011 BSD
    JOIN vValProductGroup VPG ON PG.ValProductGroupID = VPG.ValProductGroupID-- 1/24/2011 BSD
WHERE SUBSTRING(dras.GLRevenueMonth, 1, 4) = @year
	AND SUBSTRING(dras.GLRevenueMonth, 5, 2) = @month
GROUP BY vvr.Description, dras.MMSClubID, vc.ClubCode, vc.ClubName, 
	d.DepartmentID, d.Name, d.Description,
	CASE 
		WHEN vp.GLAccountNumber BETWEEN 2000 AND 2999 THEN 'Deferred'
		WHEN vp.GLAccountNumber BETWEEN 4000 AND 4999 THEN 'Non-Deferred'
		ELSE 'Other'
	END, 
	CASE 
		WHEN dras.MMSPostMonth = dras.GLRevenueMonth THEN 'Current'
		ELSE 'Prior'
	END,  
	dras.ProductID, vp.Name, vp.Description, dras.GLRevenueMonth,
	SUBSTRING(dras.GLRevenueMonth, 1, 4),
	SUBSTRING(dras.GLRevenueMonth, 5, 2),
    VPG.RevenueReportingDepartment-- 1/24/2011 BSD
ORDER BY dras.GLRevenueMonth DESC, vvr.Description, vc.ClubName, d.Description 

DROP TABLE #tmpList
DROP TABLE #Clubs

END
