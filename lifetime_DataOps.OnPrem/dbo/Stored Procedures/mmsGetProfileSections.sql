



-- Returns a result set of Profile Sections

CREATE   PROCEDURE dbo.mmsGetProfileSections
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

SELECT DISTINCT Category
  FROM dbo.vMIPCategoryItemDescription
 WHERE ActiveFlag = 1
 ORDER BY Category

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END




