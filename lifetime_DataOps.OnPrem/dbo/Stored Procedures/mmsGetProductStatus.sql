






-- Returns a result set of unique product status

CREATE PROC dbo.mmsGetProductStatus
AS
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

SELECT ValProductStatusID, Description
  FROM dbo.vValProductStatus
 ORDER BY Description



-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity



