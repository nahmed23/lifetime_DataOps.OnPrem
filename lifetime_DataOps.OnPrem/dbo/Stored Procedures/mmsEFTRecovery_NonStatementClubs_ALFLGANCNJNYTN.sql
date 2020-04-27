
CREATE   PROC [dbo].mmsEFTRecovery_NonStatementClubs_ALFLGANCNJNYTN
AS
BEGIN

-- Report Logging
DECLARE @Identity AS INT
INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
SET @Identity = @@IDENTITY

 EXEC mmsEFTRecovery '22|23|32','American Express|Discover|MasterCard|VISA'

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END

