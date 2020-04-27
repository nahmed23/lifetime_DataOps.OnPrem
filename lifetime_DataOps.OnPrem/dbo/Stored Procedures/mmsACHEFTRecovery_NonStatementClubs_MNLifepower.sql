
CREATE   PROC [dbo].[mmsACHEFTRecovery_NonStatementClubs_MNLifepower]
AS
BEGIN

-- Report Logging
DECLARE @Identity AS INT
INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
SET @Identity = @@IDENTITY

 EXEC mmsACHEFTRecovery 'West-MN-East|West-MN-LTA|West-MN-West|LifePower Yoga','Commercial Checking EFT|Individual Checking|Savings Account'

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END
