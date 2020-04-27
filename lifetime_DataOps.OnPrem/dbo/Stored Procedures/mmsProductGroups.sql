
CREATE      PROC [dbo].[mmsProductGroups]
AS
BEGIN

SET XACT_ABORT ON
SET NOCOUNT ON

---
--- Returns a listing of all products currently assigned to a 
--- Product Group along with their department and product group description
--- EXEC mmsProductGroups

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

SELECT PG.ProductID, 
       VPG.Description ProductGroupDescription, 
       P.Description ProductDescription, 
       D.Description DeptDescription, 
       VPG.ValProductGroupID, 
       VPG.SortOrder, 
       P.PackageProductFlag, 
       D.DepartmentID,
	   P.ValProductStatusID,
       VPG.RevenueReportingDepartment + '-' + Convert(Varchar,VPG.SortOrder) ReportingSortOrder,
       VPG.RevenueReportingDepartment,
       Case When VPG.RevenueReportingDepartment is Null
            Then 0
            When VPG.RevenueReportingDepartment not in ('Endurance','Group Training','LifeLab/Testing-HRM',
                                              'Nutrition Services','Nutritionals - Personal Shopper','Personal Training','Pilates',
                                              'PT-Mixed Combat Arts','Mixed Combat Arts')
            THEN 1
            Else 0
            End DeferredRevenueDepartmentFlag,
      Case When VPG.RevenueReportingDepartment is Null
            Then 0
            When VPG.RevenueReportingDepartment in ('Endurance','Group Training','LifeLab/Testing-HRM',
                                              'Nutrition Services','Nutritionals - Personal Shopper','Personal Training','Pilates',
                                              'PT-Mixed Combat Arts','Mixed Combat Arts')
            THEN 1
            Else 0
            End NonDeferredRevenueDepartmentFlag
  FROM dbo.vValProductGroup VPG
  LEFT JOIN  dbo.vProductGroup PG
    ON  PG.ValProductGroupID=VPG.ValProductGroupID
  LEFT JOIN  dbo.vProduct P
    ON  PG.ProductID=P.ProductID
  LEFT JOIN  dbo.vDepartment D
    ON  P.DepartmentID=D.DepartmentID
 WHERE VPG.ValProductGroupID NOT IN(25)

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END
