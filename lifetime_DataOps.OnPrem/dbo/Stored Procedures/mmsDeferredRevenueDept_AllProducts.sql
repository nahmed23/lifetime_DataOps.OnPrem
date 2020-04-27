

/********************************

    DeferredRevenueDepartments

********************************/

CREATE   PROC [dbo].[mmsDeferredRevenueDept_AllProducts](
@Department VARCHAR(2000) --RevenueReportingDepartment 1/31/2011 BSD
) 

AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

--=====================================================================================
--	Object:			dbo.mmsDeferredRevenueDept_AllProducts
--	Author:			Susan Myrick
--	Create Date:		
--	Description:	Returns all department products, currently displaying in the UI or not
--	Modified date:	8/6/2009 GRB: commented out WHERE clause, allowing all products (missing a revenue 
--						allocation) - not just those in the current year; deploying via dbcr_4914 on 8/13/2009
--					7/20/2009 GRB: added UNION query per revised design assoc. w/ RR391; deploying via dbcr_4799 on 8/5/2009 
--                  07/06/2010 MLL: join to vGLAccount to return RefundGLAccountNumber and DiscountGLAccount
--                  01/31/2011 BSD: @Department now accepts RevenueReportingDepartment.  Added table #MMSDepartments and joins to it.
--
--
--	EXEC mmsDeferredRevenueDept_AllProducts 'Aquatics'
--=====================================================================================


-- Report Logging
DECLARE @Identity int
INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
SET @Identity = @@IDENTITY

DECLARE @LastMonth VARCHAR(6)
DECLARE @FirstOfCurrentYear VARCHAR(6)

Set @LastMonth = LEFT(CONVERT(VARCHAR,DateAdd(month,-1,GetDate()),112),6)
Set @FirstOfCurrentYear = LEFT(CONVERT(VARCHAR,GetDate(),112),4)+'01'

CREATE TABLE #tmpList (StringField VARCHAR(50))

CREATE TABLE #Departments (Department VARCHAR(50))
EXEC procParseStringList @Department
INSERT INTO #Departments (Department) SELECT StringField FROM #tmpList --RevenueReportingDepartment 1/31/2011 BSD

---- Create table to generate ID numbers for posting months from the rates table for current allocations
CREATE TABLE #TMPPostingMonthNumber(PostingMonthID INT IDENTITY(1,1),PostingMonth VARCHAR(50))
INSERT INTO #TMPPostingMonthNumber(PostingMonth)
SELECT R.PostingMonth
  FROM vRevenueAllocationRates R
   WHERE R.PostingMonth >= @LastMonth
      Group By R.PostingMonth

   --1/31/2011 BSD
---- Create table of MMS Departments related to selected Revenue Reporting Departments
CREATE TABLE #MMSDepartments (MMSDepartmentDescription Varchar(50))
INSERT INTO #MMSDepartments
SELECT D.Description
FROM #Departments
JOIN vValProductGroup VPG ON #Departments.Department = VPG.RevenueReportingDepartment
JOIN vProductGroup PG ON VPG.ValProductGroupID = PG.ValProductGroupID
JOIN vProduct P ON PG.ProductID = P.ProductId
JOIN vDepartment D On P.DepartmentID = D.DepartmentID
GROUP BY D.Description
   --1/31/2011 BSD

---- Return Club specific Tennis allocations 

SELECT C.ClubName, D.Description AS DeptDescription, P.ProductID, P.Description AS ProductDescription,
       VRAPG.Description AS RevenueAllocationProductGroup,VPG.Description AS ProductProgramDescription, 
       PG.GLRevenueAccount, PG.GLRevenueSubAccount, P.DisplayUIFlag,PS.Description AS ProductStatusDescription,
	   VRAPG.ValRevenueAllocationProductGroupID, R.PostingMonth, R.Ratio,
       Case When tPM.PostingMonthID IS Null Then 0 Else tPM.PostingMonthID END PostingMonthID,
       GA.RefundGLAccountNumber, GA.DiscountGLAccount
       
FROM vDepartment D 
       JOIN vProduct P 
         ON D.DepartmentID=P.DepartmentID
       JOIN vValProductStatus PS
         ON PS.ValProductStatusID = P.ValProductStatusID
       JOIN #MMSDepartments #D   --1/31/2011 BSD
         ON #D.MMSDepartmentDescription = D.Description
       LEFT JOIN vProductGroupByClub PG 
         ON P.ProductID=PG.ProductID 
       LEFT JOIN vClub C
         ON C.ClubID = PG.MMSClubID
       LEFT Join vRevenueAllocationRates R
         ON PG.ValRevenueAllocationProductGroupID = R.ValRevenueAllocationProductGroupID
       LEFT JOIN #TMPPostingMonthNumber tPM
         ON tPM.PostingMonth = R.PostingMonth
       LEFT JOIN vValRevenueAllocationProductGroup VRAPG 
         ON PG.ValRevenueAllocationProductGroupID=VRAPG.ValRevenueAllocationProductGroupID
       LEFT JOIN vValProductGroup VPG
         ON PG.ValProductGroupID = VPG.ValProductGroupID
       LEFT JOIN vGLAccount GA 
         ON GA.RevenueGLAccountNumber = PG.GLRevenueAccount
Where R.PostingMonth >= @FirstOfCurrentYear Or R.PostingMonth = 0

UNION													-- begin code added 7/20/2009 GRB

------ Return allocations which are not club specific


SELECT 'Not Designated' as ClubName, D.Description AS DeptDescription, P.ProductID, P.Description AS ProductDescription,
       VRAPG.Description AS RevenueAllocationProductGroup,VPG.Description AS ProductProgramDescription, 
       PG.GLRevenueAccount, PG.GLRevenueSubAccount, P.DisplayUIFlag,PS.Description AS ProductStatusDescription,
	   VRAPG.ValRevenueAllocationProductGroupID, R.PostingMonth, R.Ratio,
       Case When tPM.PostingMonthID IS Null Then 0 Else tPM.PostingMonthID END PostingMonthID,
       GA.RefundGLAccountNumber, GA.DiscountGLAccount
       
FROM vDepartment D 
       JOIN vProduct P 
         ON D.DepartmentID=P.DepartmentID
       JOIN vValProductStatus PS
         ON PS.ValProductStatusID = P.ValProductStatusID
       JOIN #MMSDepartments #D   --1/31/2011 BSD
         ON #D.MMSDepartmentDescription = D.Description
       LEFT JOIN vProductGroup PG 
         ON P.ProductID=PG.ProductID 
       LEFT Join vRevenueAllocationRates R
         ON PG.ValRevenueAllocationProductGroupID = R.ValRevenueAllocationProductGroupID
       LEFT JOIN #TMPPostingMonthNumber tPM
         ON tPM.PostingMonth = R.PostingMonth
       LEFT JOIN vValRevenueAllocationProductGroup VRAPG 
         ON PG.ValRevenueAllocationProductGroupID=VRAPG.ValRevenueAllocationProductGroupID
       LEFT JOIN vValProductGroup VPG
         ON PG.ValProductGroupID = VPG.ValProductGroupID
       LEFT JOIN vGLAccount GA 
         ON GA.RevenueGLAccountNumber = PG.GLRevenueAccount
--	Where R.PostingMonth >= @FirstOfCurrentYear Or R.PostingMonth = 0    -- 8/6/2009 GRB 


Drop Table #TMPPostingMonthNumber
Drop Table #Departments
Drop Table #tmpList

														-- end code added 7/20/2009 GRB


-- Report Logging
UPDATE HyperionReportLog
SET EndDateTime = getdate()
WHERE ReportLogID = @Identity

END
