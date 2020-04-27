


---------------------------  mmsDeferredRevenueDept_SalesSummary_History  ---------------------------

CREATE   PROC [dbo].[mmsDeferredRevenueDept_SalesSummary_History] (
  @YearMonth VARCHAR(10),
  @Department VARCHAR(2000)
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- =============================================
-- Object:			mmsDeferredRevenueDept_SalesSummary_History
-- Author:			Susan Myrick
-- Create date: 	9/3/08
-- Description:		Returns a summary of a selected month's transactions allocated to their revenue month
-- 		
-- Parameters:		Transaction month and product department
--	
-- Modified:         2/4/2011 BSD @Department parameter now RevenueReportingDepartment.  Added join to vValProductGroup and vProductGroup to support.
-- =============================================


-- Report Logging
DECLARE @Identity int
INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
SET @Identity = @@IDENTITY

CREATE TABLE #tmpList (StringField VARCHAR(50))

CREATE TABLE #Departments (Department VARCHAR(50))
EXEC procParseStringList @Department
INSERT INTO #Departments (Department) SELECT StringField FROM #tmpList


SELECT	C.GLClubID, C.ClubName, DRAS.RevenueAllocationProductGroupDescription, 
        P.Description AS ProductDescription, DRAS.MMSPostMonth, DRAS.GLRevenueMonth, 
        DRAS.RevenueMonthAllocation,DRAS.TransactionType		
FROM vDeferredRevenueAllocationSummary DRAS
        JOIN  vCLUB C
            ON  C.ClubID=DRAS.MMSClubID
        JOIN  vProduct P
            ON  DRAS.ProductID=P.ProductID
--        JOIN vDepartment D  --2/4/2011 BSD
--            ON DRAS.ProductDepartmentID = D.DepartmentID  --2/4/2011 BSD
        JOIN vProductGroup PG  --2/4/2011 BSD
            ON P.ProductID = PG.ProductID  --2/4/2011 BSD
        JOIN vValProductGroup VPG  --2/4/2011 BSD
            ON PG.ValProductGroupID = VPG.ValProductGroupID  --2/4/2011 BSD
        JOIN #Departments #D
            ON #D.Department = VPG.RevenueReportingDepartment  --2/4/2011 BSD
WHERE DRAS.MMSPostMonth=@YearMonth

DROP TABLE #Departments
DROP TABLE #tmpList

-- Report Logging
UPDATE HyperionReportLog
SET EndDateTime = getdate()
WHERE ReportLogID = @Identity


END
