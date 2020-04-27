

--THIS PROCEDURE EXECUTES THE STORED PROCEDURE mmsGetEmployees FOR ALL CLUBS 


CREATE  PROCEDURE dbo.mmsGetEmployees_All
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON
-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

  EXEC mmsGetEmployees 'All'

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END



