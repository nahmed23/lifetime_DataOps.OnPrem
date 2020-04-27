



-- Returns a result set of Profile Items

CREATE   PROCEDURE dbo.mmsGetProfileItems
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON


-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

SELECT DISTINCT Item AS ItemDescription
  FROM dbo.vMIPCategoryItemDescription
 WHERE ActiveFlag = 1
 ORDER BY Item

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END




