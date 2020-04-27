

---------------------------  mmsDeferredRevenueDept_SingleMonthsAllocation  ---------------------------
CREATE    PROC [dbo].[mmsDeferredRevenueDept_SingleMonthsAllocation] (
	@RevenueYearMonth INT,
    @Department VARCHAR(2000)
)
AS
BEGIN

SET XACT_ABORT ON
SET NOCOUNT ON


-- =============================================
-- Object:			dbo.mmsDeferredRevenueDept_SingleMonthsAllocation
-- Author:			Susan Myrick
-- Create date: 	9/3/08
-- Description:		Returns a Department's revenue figures for each club in a selected month.
--					Only departments with deferred revenue are available.
--                  
-- Modified Date:	1/24/2011 BSD: Update procedure to filter on #Departments joined to VPG.RevenueReportingDepartment
--                  5/13/2009 GRB: expose all ValProductGroup xSortOrder values by putting the original query 
--						into a sub select; also added filtering conditions and ORDER BY clause; deploying 5/20/2009 via dbcr_4555
--					1/26/2009 GRB: added aquatics code;
--	
-- Exec mmsDeferredRevenueDept_SingleMonthsAllocation '201002', 'Tennis|Camps'

-- Report Logging
DECLARE @Identity AS INT
INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
SET @Identity = @@IDENTITY

CREATE TABLE #tmpList (StringField VARCHAR(50))
CREATE TABLE #Departments (Department VARCHAR(50))

IF @Department = 'All'                                                                                    -- 1/24/2011 BSD
 BEGIN                                                                                                    -- 1/24/2011 BSD
  INSERT INTO #Departments (Department) SELECT Distinct RevenueReportingDepartment FROM vValProductGroup -- 1/24/2011 BSD
 END                                                                                                      -- 1/24/2011 BSD
ELSE                                                                                                      -- 1/24/2011 BSD
 BEGIN                                                                                                    -- 1/24/2011 BSD
  EXEC procParseStringList @Department
  INSERT INTO #Departments (Department) SELECT StringField FROM #tmpList
 END                                                                                                      -- 1/24/2011 BSD



SELECT      
	Revenue.RegionDescription AS RegionDescription, Revenue.ClubCode, Revenue.RevenueAllocationProductGroupDescription, 
	Revenue.ProductDescription AS ProductDescription, Revenue.GLRevenueMonth, Revenue.RevenueMonthAllocation, 
	Revenue.ClubName, Revenue.MMSClubID AS MMSClubID, Revenue.GLClubID, Revenue.ProductID, 
	VPG.ValProductGroupID,
	VPG.Description AS ProductGroupDescription, GetDate()-1 AS ReportDate,
	Revenue.MemberActivitiesRegionDescription AS MemberActivitiesRegionDescription, Revenue.MMSPostMonth,
	Revenue.TransactionType, 
    VPG.RevenueReportingDepartment + '-' + Convert(Varchar,VPG.SortOrder) ReportSortOrder,                        -- 1/24/2011 BSD
--	CASE                                                                                         -- 1/24/2011 BSD
--       WHEN #Departments.Department = 'Tennis' THEN VPG.TennisSortOrder                        -- 1/24/2011 BSD
--       WHEN #Departments.Department = 'Pro Shop' THEN VPG.TennisSortOrder                      -- 1/24/2011 BSD
----	   WHEN #Departments.Department = 'Member Activities' THEN VPG.MemberActivitiesSortOrder -- 1/24/2011 BSD
--	   WHEN #Departments.Department = 'Aquatics' THEN VPG.AquaticsSortOrder                      -- 1/24/2011 BSD
--	   ELSE VPG.MemberActivitiesSortOrder                                                        -- 1/24/2011 BSD
--	END ReportSortOrder,                                                                         -- 1/24/2011 BSD
    #Departments.Department AS DepartmentDescription, D.DepartmentID
FROM vValProductGroup VPG
	LEFT JOIN (												-- 5/13/2009 GRB
		SELECT	R.Description AS RegionDescription, C.ClubCode, DRAS.RevenueAllocationProductGroupDescription, 
			P.Description as ProductDescription, DRAS.GLRevenueMonth, DRAS.RevenueMonthAllocation, 
			C.ClubName, C.ClubID AS MMSClubID,C.GLClubID, DRAS.ProductID, VPG.ValProductGroupID,
			VPG.Description AS ProductGroupDescription, GetDate()-1 AS ReportDate,
			VMAR.Description AS MemberActivitiesRegionDescription, DRAS.MMSPostMonth,
			DRAS.TransactionType, 
            VPG.RevenueReportingDepartment + '-' + Convert(Varchar,VPG.SortOrder) ReportSortOrder                             -- 1/24/2011 BSD
--			CASE WHEN D.Description = 'Tennis' THEN VPG.TennisSortOrder                                      -- 1/24/2011 BSD
--				 WHEN D.Description = 'Pro Shop' THEN VPG.TennisSortOrder                                    -- 1/24/2011 BSD
----				 WHEN D.Description = 'Member Activities' THEN VPG.MemberActivitiesSortOrder             -- 1/24/2011 BSD
--				 WHEN D.Description = 'Aquatics' THEN VPG.AquaticsSortOrder					-- 1/26/2009 GRB -- 1/24/2011 BSD
--			     ELSE VPG.MemberActivitiesSortOrder                                                          -- 1/24/2011 BSD
--			END ReportSortOrder                                                                              -- 1/24/2011 BSD
		FROM vDeferredRevenueAllocationSummary DRAS
			 JOIN vCLUB C ON DRAS.MMSClubID=C.ClubID
			 JOIN vValRegion R ON C.ValRegionID=R.ValRegionID
			 JOIN vProduct P ON DRAS.ProductID=P.ProductID
			 JOIN vProductGroup PG ON DRAS.ProductID = PG.ProductID
			 JOIN vValProductGroup VPG ON PG.ValProductGroupID = VPG.ValProductGroupID
			 JOIN vDepartment D ON P.DepartmentID = D.DepartmentID
			 JOIN #Departments #D ON VPG.RevenueReportingDepartment = #D.Department
			 LEFT JOIN vValMemberActivityRegion VMAR ON VMAR.ValMemberActivityRegionID = C.ValMemberActivityRegionID
		WHERE DRAS.GLRevenueMonth = @RevenueYearMonth        
			) Revenue ON VPG.ValProductGroupID   = Revenue.ValProductGroupID
    JOIN vProduct P
      ON P.ProductID = Revenue.ProductID
    JOIN vDepartment D
      ON D.DepartmentID = P.DepartmentID
    JOIN #Departments #Departments
      ON #Departments.Department = VPG.RevenueReportingDepartment                                                                -- 1/24/2011 BSD
--WHERE (#Departments.Department = ('Tennis') AND VPG.TennisSortOrder IS NOT NULL)				-- 5/13/2009 GRB                 -- 1/24/2011 BSD
--   OR (#Departments.Department = ('Pro Shop') AND VPG.TennisSortOrder IS NOT NULL)                                             -- 1/24/2011 BSD
--   -----OR (#Departments.Department = 'Member Activities' AND VPG.MemberActivitiesSortOrder IS NOT NULL)		-- 5/13/2009 GRB -- 1/24/2011 BSD
--   OR (#Departments.Department = 'Aquatics' AND VPG.AquaticsSortOrder IS NOT NULL)						-- 5/13/2009 GRB     -- 1/24/2011 BSD
--   OR (VPG.MemberActivitiesSortOrder IS NOT NULL)                                                                              -- 1/24/2011 BSD
ORDER BY ReportSortOrder																	-- 5/13/2009 GRB

 -- Report Logging
UPDATE HyperionReportLog
SET EndDateTime = getdate()
WHERE ReportLogID = @Identity

DROP TABLE #Departments
DROP TABLE #tmpList

END
