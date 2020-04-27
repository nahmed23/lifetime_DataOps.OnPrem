


/**************************************

       RevenueAllocationByGroup

**************************************/

---------------------------  mmsDeferredRevenueDept_AnnualAllocation  ---------------------------
CREATE     PROC [dbo].[mmsDeferredRevenueDept_AnnualAllocation](
	@RevenueYear INT,
    @Department VARCHAR(2000)
)
AS
BEGIN

SET XACT_ABORT ON
SET NOCOUNT ON

-- =============================================
-- Object:			dbo.mmsDeferredRevenueDept_AnnualAllocation
-- Author:			Susan Myrick
-- Create date: 	9/3/08
-- Description:		Returns selected Department allocated revenue figures 
--					and months for each club in a selected year 
--
-- Modified:        1/24/2011 BSD: Updated parameter @Department to accept 'ALL'
--                                 Join #Departments to VPG.RevenueReportingDepartment
--	
-- Exec mmsDeferredRevenueDept_AnnualAllocation '2008','Tennis|Pro Shop'
-- =============================================

-- Report Logging
DECLARE @Identity AS INT
INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
SET @Identity = @@IDENTITY

CREATE TABLE #tmpList (StringField VARCHAR(50))
CREATE TABLE #Departments (Department VARCHAR(50))

IF @Department = 'All'                                                                                   -- 1/24/2011 BSD
 BEGIN                                                                                                   -- 1/24/2011 BSD
  INSERT INTO #Departments (Department) SELECT Distinct RevenueReportingDepartment FROM vValProductGroup -- 1/24/2011 BSD
 END                                                                                                     -- 1/24/2011 BSD
ELSE                                                                                                     -- 1/24/2011 BSD
 BEGIN                                                                                                   -- 1/24/2011 BSD
  EXEC procParseStringList @Department
  INSERT INTO #Departments (Department) SELECT StringField FROM #tmpList
 END                                                                                                     -- 1/24/2011 BSD

SELECT	R.Description AS RegionDescription, C.ClubCode, DRAS.RevenueAllocationProductGroupDescription, 
	P.Description as ProductDescription, DRAS.GLRevenueMonth, DRAS.RevenueMonthAllocation, 
	C.ClubName, C.ClubID AS MMSClubID,C.GLClubID, DRAS.ProductID, VPG.ValProductGroupID,
	VPG.Description AS ProductGroupDescription, GetDate()-1 AS ReportDate,
	VMAR.Description AS MemberActivitiesRegionDescription, DRAS.MMSPostMonth,
	DRAS.TransactionType, D.Description AS ProductDepartment,
    VPG.RevenueReportingDepartment       -- 1/24/2011 BSD
FROM vDeferredRevenueAllocationSummary DRAS
     JOIN vCLUB C
       ON DRAS.MMSClubID=C.ClubID
     JOIN vValRegion R
       ON C.ValRegionID=R.ValRegionID
     JOIN vProduct P 
       ON DRAS.ProductID=P.ProductID
     JOIN vProductGroup PG
       ON DRAS.ProductID = PG.ProductID
     JOIN vValProductGroup VPG
       ON PG.ValProductGroupID = VPG.ValProductGroupID
     JOIN vDepartment D
       ON P.DepartmentID = D.DepartmentID
     JOIN #Departments #D
       ON VPG.RevenueReportingDepartment = #D.Department   -- 1/24/2011 BSD
     LEFT JOIN vValMemberActivityRegion VMAR
       ON VMAR.ValMemberActivityRegionID = C.ValMemberActivityRegionID
WHERE Substring(DRAS.GLRevenueMonth,1,4)= @RevenueYear

 -- Report Logging
UPDATE HyperionReportLog
SET EndDateTime = getdate()
WHERE ReportLogID = @Identity

DROP TABLE #Departments
DROP TABLE #tmpList

END
