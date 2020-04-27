



/***************************

   ParticipantCountReporting

***************************/

CREATE PROCEDURE [dbo].[mmsDeferredRevenueDept_ParticipationCounts] (
  @StartYearMonth INT,
  @EndYearMonth INT
)


AS
BEGIN

SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
DECLARE @Identity AS INT
INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
SET @Identity = @@IDENTITY

SELECT SUBSTRING(DRAS.GLRevenueMonth,1,4) AS ReportYear,
       SUBSTRING(DRAS.GLRevenueMonth,5,2) AS ReportMonth,
       VMAR.Description AS RegionName,
       C.ClubID AS PostingClubID,
       C.ClubName AS PostingClubName,
       D.Description AS Department, -- Deptdescription
       VPG.valProductGroupId AS ProgramID,
       VPG.Description AS Program, --> the same as Productgroupdescription
       PG.ProductID AS Productid, 
       P.Description AS ProductDescription,
       DRAS.mmsPostMonth AS PostMonth,
       DRAS.TransactionType AS TranTypeDescription,
       DRAS.Quantity AS OriginalItemQuantity,
       DRAS.RevenueMonthQuantityAllocation AS AllocatedItemQuantity,
       VPG.RevenueReportingDepartment AS RevenueReportingDepartment
  FROM vDeferredRevenueAllocationSummary DRAS
  JOIN vClub C ON C.ClubID = DRAS.MMSClubID
  JOIN vValMemberActivityRegion VMAR ON VMAR.ValMemberActivityRegionID = C.ValMemberActivityRegionID
  JOIN vProduct P ON DRAS.ProductID = P.ProductID
  JOIN vDepartment D ON P.DepartmentID = D.DepartmentID
  JOIN vProductGroup PG ON PG.ProductID = P.ProductID
  JOIN vValProductGroup VPG ON VPG.valProductGroupID = PG.valProductGroupID
 WHERE GLRevenueMonth>=@StartYearMonth  AND GLRevenueMonth<=@EndYearMonth 

-- Report Logging
UPDATE HyperionReportLog
SET EndDateTime = getdate()
WHERE ReportLogID = @Identity

END
