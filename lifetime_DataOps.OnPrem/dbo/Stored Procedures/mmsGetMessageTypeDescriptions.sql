




-- Returns a result set of Message Type Descriptions

CREATE PROC dbo.mmsGetMessageTypeDescriptions
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

SELECT Description
  FROM dbo.vValMembershipMessageType
 ORDER BY Description

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity
 
END







