




----
---- This procedure returns information all delivered sessions Month to date
---- for All clubs
----

----Exec mmsPT_DSSR_DeliveredSessions_MTD_AllClubs

CREATE     PROCEDURE dbo.mmsPT_DSSR_DeliveredSessions_MTD_AllClubs

AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

DECLARE @FirstOfMonth DATETIME
DECLARE @Today    DATETIME


SET @FirstOfMonth = CONVERT(DATETIME,CONVERT(VARCHAR,(GETDATE() - DAY(GETDATE()-1)),110),110)
SET @Today = CONVERT(DATETIME,CONVERT(VARCHAR,GETDATE(),110),110)

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY


EXEC mmsPackage_SessionsDetail 0,@FirstOfMonth,@Today



-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END




