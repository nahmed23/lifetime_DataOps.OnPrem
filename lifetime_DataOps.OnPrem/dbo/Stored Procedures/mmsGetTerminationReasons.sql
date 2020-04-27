









-- Returns a result set of Termination Reason Descriptions

CREATE     PROC dbo.mmsGetTerminationReasons
AS
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

SELECT valterminationreasonid, Description, sortorder
  FROM dbo.vValTerminationReason
ORDER BY Description


-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity







