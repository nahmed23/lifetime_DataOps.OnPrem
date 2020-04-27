

-- returns date and time of last checkin per club
--

CREATE PROC dbo.mmsRepDx

AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

SELECT C.ClubName, MAX ( MU.UsageDateTime ) AS UsageDateTime, 
       MU.UsageDateTimeZone
  FROM dbo.vClub C 
  JOIN dbo.vMemberUsage MU 
       ON MU.ClubID = C.ClubID
 WHERE MU.UsageDateTime>DATEADD(day,-2,GETDATE()) 
 GROUP BY C.ClubName, MU.UsageDateTimeZone
 
-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END 




