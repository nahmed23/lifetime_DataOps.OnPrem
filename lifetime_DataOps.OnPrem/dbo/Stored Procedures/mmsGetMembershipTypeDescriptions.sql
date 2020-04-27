





-- Returns a result set of Membership Type Descriptions

CREATE  PROC dbo.mmsGetMembershipTypeDescriptions
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

SELECT ProductID, Description
  FROM dbo.vProduct
 WHERE DepartmentID = 1
 ORDER BY Description

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END






