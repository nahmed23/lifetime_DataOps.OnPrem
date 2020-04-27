


--------------------------------------------------------------------7
/*
Two stored procedures need to be updated to remove special case logic for Refunds in calculating 
the "GLRevenueMonth" column. Refunds will now be allocated like any other transaction type.

Stored procedures:
mmsDeferredRevenueDept_RevenueAllocationCalc
mmsDeferredRevenueDept_RevenueAllocationCalcAndInsert
*/

---------------------------  mmsDeferredRevenueDept_RevenueAllocationCalc  ---------------------------

CREATE Procedure [dbo].[mmsDeferredRevenueDept_RevenueAllocationCalc](
    @Department VARCHAR(2000)
)
AS
BEGIN
SET XACT_ABORT  ON
SET NOCOUNT  ON

------=================================================================================================
------Object:				dbo.mmsDeferredRevenueDept_RevenueAllocationCalc
------Author:				Susan Myrick
------Create Date:			8/30/08
------Description:			Calculates Revenue allocation for transactions in the sale month and department  
------						passed by the report user.
------Parameters:			The first of the month to be reported and the product department.
------                      04/27/2010 MLL Removed special logic for Refunds in calculating GLRevenueMonth
------                      02/04/2011 BSD @Department now a RevenueReportingDepartment.  Added join to ValProductGroup to support
------
------ EXEC mmsDeferredRevenueDept_RevenueAllocationCalc 'Member Activities'
------==================================================================================================


DECLARE @StartDatePriorMonth  AS VARCHAR(6)
DECLARE @StartMonth AS VARCHAR(6)
DECLARE @EndDate AS DATETIME
DECLARE @YearFromStartDatePriorMonth AS VARCHAR(6)
DECLARE @StartDate AS DATETIME

SET @StartDate = CONVERT(DATETIME,LEFT(CONVERT(VARCHAR,GetDate()-1,110),2)+ '/01/'+ LEFT(CONVERT(VARCHAR,GetDate()-1,112),4))
SET @StartDatePriorMonth = LEFT(CONVERT(VARCHAR,DATEADD(m,-1,@StartDate),112),6)
SET @StartMonth = LEFT(CONVERT(VARCHAR,@StartDate,112),6)
SET @EndDate = DATEADD(m,1,@StartDate)
SET @YearFromStartDatePriorMonth = LEFT(CONVERT(VARCHAR,DATEADD(m,-1,@StartDate),112),6)+100

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

CREATE TABLE #tmpList (StringField VARCHAR(50))

CREATE TABLE #Departments (Department VARCHAR(50))
EXEC procParseStringList @Department
INSERT INTO #Departments (Department) SELECT StringField FROM #tmpList

------ Create a temp table 1 to hold Club specific deferred revenue allocations 
CREATE TABLE #TMPDefAllocation1(MMSPostingClubID INT, AllocationProductGroupDescription VARCHAR(50),MMSProductID INT,
                               MMSPostMonth VARCHAR(6),GLRevenueAccount VARCHAR(5),GLRevenueSubAccount VARCHAR(11),
                               GLRevenueMonth VARCHAR(6), RevenueMonthAllocation MONEY, TransactionType VARCHAR(50),
                               ProductDepartmentID VARCHAR(2), PostingRegionDescription VARCHAR(50),PostingClubName VARCHAR(50),
                               DeptDescription VARCHAR(50),ProductDescription VARCHAR(50),TotalItemAmount MONEY, 
                               ValRevenueAllocationProductGroupID INT,Ratio DECIMAL(7,5),AccumulatedRatio DECIMAL(7,5))
INSERT INTO #TMPDefAllocation1(MMSPostingClubID,AllocationProductGroupDescription,MMSProductID,
                               MMSPostMonth,GLRevenueAccount,GLRevenueSubAccount, GLRevenueMonth, 
                               RevenueMonthAllocation, TransactionType,ProductDepartmentID, PostingRegionDescription,
                               PostingClubName,DeptDescription,ProductDescription,TotalItemAmount, 
                               ValRevenueAllocationProductGroupID,Ratio,AccumulatedRatio)


Select MMSR.PostingClubID,VRAPG.Description,MMSR.ProductID,
       @StartMonth AS MMSPostMonth,PGbyC.GLRevenueAccount,PGbyC.GLRevenueSubAccount,
       CASE WHEN  RA2.PostingMonth = 0
             THEN @StartMonth
            WHEN RA2.PostingMonth <@StartMonth
             THEN @StartMonth
            ELSE RA2.PostingMonth
        END GLRevenueMonth,
       CASE -----WHEN MMSR.TranTypeDescription = 'Refund'
             -----THEN Sum(MMSR.ItemAmount)*RA2.Ratio
            WHEN RA2.PostingMonth = 0 
             THEN Sum(MMSR.ItemAmount)
            WHEN RA2.PostingMonth = @StartDatePriorMonth
             THEN Sum(MMSR.ItemAmount) * RA2.AccumulatedRatio
            ELSE Sum(MMSR.ItemAmount) * RA2.Ratio
        END RevenueMonthAllocation,
       MMSR.TranTypeDescription, MMSR.DepartmentID,MMSR.PostingRegiondescription,
        MMSR.PostingClubName, MMSR.DeptDescription, MMSR.ProductDescription,Sum(MMSR.ItemAmount)AS TotalItemAmount,
        VRAPG.ValRevenueAllocationProductGroupID,RA2.Ratio,RA2.AccumulatedRatio
      
From vMMSRevenueReportSummary MMSR
JOIN vProductGroupByClub PGbyC
    ON PGbyC.MMSClubID = MMSR.PostingClubID
    AND PGbyC.ProductID = MMSR.ProductID
JOIN vRevenueAllocationRates RA2
    ON RA2.ValRevenueAllocationProductGroupID = PGbyC.ValRevenueAllocationProductGroupID
JOIN vValRevenueAllocationProductGroup VRAPG
    ON PGbyC.ValRevenueAllocationProductGroupID = VRAPG.ValRevenueAllocationProductGroupID
JOIN vValProductGroup VPG   --2/4/2011 BSD
  ON PGbyC.ValProductGroupID = VPG.ValProductGroupID  --2/4/2011 BSD
JOIN #Departments #D  --2/4/2011 BSD
  ON #D.Department = VPG.RevenueReportingDepartment  --2/4/2011 BSD
Where MMSR.PostDateTime >= @StartDate
  AND MMSR.PostDateTime < @EndDate
  AND (RA2.PostingMonth >= @StartDatePriorMonth or RA2.PostingMonth = 0)
  AND (RA2.ActivityFinalPostingMonth < @YearFromStartDatePriorMonth OR RA2.ActivityFinalPostingMonth IS Null )
Group BY MMSR.PostingClubID,MMSR.ProductID,RA2.PostingMonth,RA2.AccumulatedRatio,RA2.Ratio,
         VRAPG.Description,PGbyC.GLRevenueAccount,PGbyC.GLRevenueSubAccount,MMSR.TranTypeDescription,
         MMSR.DepartmentID,MMSR.PostingRegiondescription,
        MMSR.PostingClubName, MMSR.DeptDescription, MMSR.ProductDescription,
        VRAPG.ValRevenueAllocationProductGroupID,RA2.Ratio,RA2.AccumulatedRatio
Order by MMSR.PostingClubID,MMSR.ProductID 


------ Create a temp table 2 to hold Non-Club specific deferred revenue allocations 
CREATE TABLE #TMPDefAllocation2(MMSPostingClubID INT,AllocationProductGroupDescription VARCHAR(50),MMSProductID INT,
                               MMSPostMonth VARCHAR(6),GLRevenueAccount VARCHAR(5),GLRevenueSubAccount VARCHAR(11),
                               GLRevenueMonth VARCHAR(6), RevenueMonthAllocation MONEY, TransactionType VARCHAR(50),
                               ProductDepartmentID VARCHAR(2), PostingRegionDescription VARCHAR(50),PostingClubName VARCHAR(50),
                               DeptDescription VARCHAR(50),ProductDescription VARCHAR(50),TotalItemAmount MONEY, 
                               ValRevenueAllocationProductGroupID INT,Ratio DECIMAL(7,5),AccumulatedRatio DECIMAL(7,5))
INSERT INTO #TMPDefAllocation2(MMSPostingClubID,AllocationProductGroupDescription,MMSProductID,
                               MMSPostMonth, GLRevenueAccount,GLRevenueSubAccount,GLRevenueMonth, 
                               RevenueMonthAllocation,TransactionType,ProductDepartmentID, PostingRegionDescription,
                               PostingClubName,DeptDescription,ProductDescription,TotalItemAmount, 
                               ValRevenueAllocationProductGroupID,Ratio,AccumulatedRatio)

Select MMSR.PostingClubID,VRAPG.Description,MMSR.ProductID,
       @StartMonth AS MMSPostMonth,PG.GLRevenueAccount,PG.GLRevenueSubAccount,
       CASE WHEN  RA.PostingMonth = 0 OR RA.PostingMonth IS Null
             THEN @StartMonth
            WHEN RA.PostingMonth <@StartMonth
             THEN @StartMonth
            ELSE RA.PostingMonth
        END GLRevenueMonth,
       CASE ----WHEN MMSR.TranTypeDescription = 'Refund'
            ----- THEN Sum(MMSR.ItemAmount)* RA.Ratio
            WHEN RA.PostingMonth = 0 OR RA.PostingMonth IS Null
             THEN Sum(MMSR.ItemAmount)
            WHEN RA.PostingMonth = @StartDatePriorMonth
             THEN Sum(MMSR.ItemAmount) * RA.AccumulatedRatio
            ELSE Sum(MMSR.ItemAmount) * RA.Ratio
        END RevenueMonthAllocation,
        MMSR.TranTypeDescription, MMSR.DepartmentID, MMSR.PostingRegiondescription,
        MMSR.PostingClubName, MMSR.DeptDescription, MMSR.ProductDescription,Sum(MMSR.ItemAmount)AS TotalItemAmount,
        VRAPG.ValRevenueAllocationProductGroupID,RA.Ratio,RA.AccumulatedRatio
      
From vMMSRevenueReportSummary MMSR
LEFT JOIN vProductGroupByClub PGbyC
    ON PGbyC.MMSClubID = MMSR.PostingClubID
    AND PGbyC.ProductID = MMSR.ProductID
LEFT JOIN vProductGroup PG
    ON PG.ProductID = MMSR.ProductID
LEFT JOIN vRevenueAllocationRates RA
    ON RA.ValRevenueAllocationProductGroupID = PG.ValRevenueAllocationProductGroupID
LEFT JOIN vValRevenueAllocationProductGroup VRAPG
    ON PG.ValRevenueAllocationProductGroupID = VRAPG.ValRevenueAllocationProductGroupID
LEFT JOIN vValProductGroup VPG --2/4/2011 BSD
    ON PG.ValProductGroupID = VPG.ValProductGroupID --2/4/2011 BSD
JOIN #Departments #D
    ON VPG.RevenueReportingDepartment = #D.Department
Where PGbyC.ProductGroupByClubID Is Null
  AND MMSR.PostDateTime >= @StartDate
  AND MMSR.PostDateTime < @EndDate
  AND (RA.PostingMonth >= @StartDatePriorMonth or RA.PostingMonth = 0 OR RA.PostingMonth IS Null)
  AND (RA.ActivityFinalPostingMonth < @YearFromStartDatePriorMonth OR RA.ActivityFinalPostingMonth IS Null )
  AND (PG.ValProductGroupID <> 25 OR PG.ValProductGroupID Is Null)
Group BY MMSR.PostingClubID,MMSR.ProductID,RA.PostingMonth,RA.AccumulatedRatio,RA.Ratio,
         VRAPG.Description,PG.GLRevenueAccount,PG.GLRevenueSubAccount,MMSR.TranTypeDescription, 
         MMSR.DepartmentID,MMSR.PostingRegiondescription,
        MMSR.PostingClubName, MMSR.DeptDescription, MMSR.ProductDescription,
        VRAPG.ValRevenueAllocationProductGroupID,RA.Ratio,RA.AccumulatedRatio
Order by MMSR.PostingClubID,MMSR.ProductID 

---- Combine the results from both tables to create a single data set
Select MMSPostingClubID,AllocationProductGroupDescription,MMSProductID,
       MMSPostMonth,GLRevenueAccount,GLRevenueSubAccount,GLRevenueMonth, RevenueMonthAllocation,
       TransactionType,ProductDepartmentID,PostingRegionDescription,
       PostingClubName,DeptDescription,ProductDescription,TotalItemAmount, 
       ValRevenueAllocationProductGroupID,Ratio,AccumulatedRatio
       from #TMPDefAllocation1

UNION ALL

Select MMSPostingClubID,AllocationProductGroupDescription,MMSProductID,
       MMSPostMonth,GLRevenueAccount,GLRevenueSubAccount,GLRevenueMonth, RevenueMonthAllocation,
       TransactionType,ProductDepartmentID,PostingRegionDescription,
       PostingClubName,DeptDescription,ProductDescription,TotalItemAmount, 
       ValRevenueAllocationProductGroupID,Ratio,AccumulatedRatio
       from #TMPDefAllocation2

DROP TABLE #TMPDefAllocation1
DROP TABLE #TMPDefAllocation2
DROP TABLE #Departments
DROP TABLE #tmpList

 -- Report Logging
UPDATE HyperionReportLog
SET EndDateTime = getdate()
WHERE ReportLogID = @Identity

END
