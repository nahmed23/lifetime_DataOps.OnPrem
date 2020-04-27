
CREATE   PROC [dbo].mmsEFTRecovery_NonStatementClubs_AZILMONV
AS
BEGIN

-- Report Logging
DECLARE @Identity AS INT
INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
SET @Identity = @@IDENTITY

 EXEC mmsEFTRecovery '20|17','American Express|Discover|MasterCard|VISA'

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END

