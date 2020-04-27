
--Delinquent Aging
CREATE PROC [dbo].[mmsDeliquent_Aging_Scheduled_RegionSet2] AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

EXEC mmsDeliquent_Aging_Scheduled '19|20|15|17|33' --East-Michigan|East-Midwest|West-Mountain|West-Desert|East-Great Lakes

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END
