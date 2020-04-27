
/* 9 */
CREATE PROC [dbo].[mmsDeliquent_CreditBalance_Scheduled_RegionSet1] AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

EXEC mmsDeliquent_CreditBalance_Scheduled '22|23|26|27|28|29|32|35|36|37' --East-Northeast|East-Southeast|West-TXDallas|West-TXCentral|West-TXHouston|LifePower|East-Atlanta|West-MN-East|West-MN-LTA|West-MN-West

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END
