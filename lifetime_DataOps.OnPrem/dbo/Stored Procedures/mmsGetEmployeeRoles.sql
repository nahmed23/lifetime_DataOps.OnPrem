







-- Returns a result set of unique Employee Roles

CREATE   PROC dbo.mmsGetEmployeeRoles
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

SELECT ValEmployeeRoleID,Description
  FROM dbo.vValEmployeeRole
ORDER BY Description


-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END










