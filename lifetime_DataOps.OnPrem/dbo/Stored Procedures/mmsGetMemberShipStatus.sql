







-- Returns a result set of Membership Statuses

CREATE   PROCEDURE dbo.mmsGetMemberShipStatus
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

SELECT Description AS MemberShipStatus,valMemberShipStatusId
  FROM dbo.vValMemberShipStatus
 ORDER BY Description

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END






