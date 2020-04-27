

CREATE PROC dbo.mmsEFTRecovery_StatementClubs
AS
BEGIN

-- Report Logging
DECLARE @Identity AS INT
INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
SET @Identity = @@IDENTITY

 EXEC dbo.mmsEFTRecovery;1 'Minnesota','American Express|Discover|MasterCard|VISA'  

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END



