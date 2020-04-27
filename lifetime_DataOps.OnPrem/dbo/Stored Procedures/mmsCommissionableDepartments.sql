




--
-- Returns recordset listing depts that are commissionable
--     to be used in the CommissionableSales brio report
--
-- Parameters: None
--

CREATE PROC dbo.mmsCommissionableDepartments
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

SELECT DISTINCT D.Description AS DepartmentDescription
  FROM dbo.vClubProduct CP
  JOIN dbo.vProduct P
       ON CP.ProductID = P.ProductID
  JOIN dbo.vDepartment D 
       ON P.DepartmentID = D.DepartmentID
 WHERE CP.ValCommissionableID IN (1, 3) 
 ORDER BY D.Description

-- Report Logging
UPDATE HyperionReportLog
SET EndDateTime = getdate()
WHERE ReportLogID = @Identity

END





