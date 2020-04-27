
CREATE   PROC [dbo].[mmsACHEFTRecovery_NonStatementClubs_COONMIUT]
AS
BEGIN

-- Report Logging
DECLARE @Identity AS INT
INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
SET @Identity = @@IDENTITY

 EXEC mmsACHEFTRecovery 'West-Mountain|East-Great Lakes','Commercial Checking EFT|Individual Checking|Savings Account'

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END
