

CREATE       PROC [dbo].[mmsMindBodyProductGroups]
AS
BEGIN

SET XACT_ABORT ON
SET NOCOUNT ON
---
--- Returns a listing of all Mind Body Products currently assigned to a 
--- Mind Body Product Group along with their department and product group description
---


-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

SELECT PG.ProductID, VPG.Description ProductGroupDescription, P.Description ProductDescription, 
D.Description DeptDescription, VPG.ValProductGroupID, VPG.SortOrder, P.PackageProductFlag
FROM dbo.vValProductGroup VPG
 LEFT JOIN  dbo.vProductGroup PG
   ON  PG.ValProductGroupID=VPG.ValProductGroupID
 LEFT JOIN  dbo.vProduct P
   ON  PG.ProductID=P.ProductID
 LEFT JOIN  dbo.vDepartment D
   ON  P.DepartmentID=D.DepartmentID
WHERE D.DepartmentID = 10 --( Mind Body )

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END

