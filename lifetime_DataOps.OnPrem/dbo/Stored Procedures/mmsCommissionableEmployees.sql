





--
-- Returns recordset listing employees that are commissionable
--     to be used in the CommissionableSales brio report
--
-- Parameters: None
--

CREATE  PROC dbo.mmsCommissionableEmployees
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

SELECT VER.Description RoleDescription, E.EmployeeID, E.FirstName, 
       E.LastName, VER.CommissionableFlag 
  FROM dbo.vEmployee E
  JOIN dbo.vEmployeeRole ER
       ON ER.EmployeeID = E.EmployeeID
  JOIN dbo.vValEmployeeRole VER 
       ON VER.ValEmployeeRoleID = ER.ValEmployeeRoleID
 WHERE VER.CommissionableFlag = 1 AND 
       E.ActiveStatusFlag = 1

-- Report Logging
UPDATE HyperionReportLog
SET EndDateTime = getdate()
WHERE ReportLogID = @Identity

END






