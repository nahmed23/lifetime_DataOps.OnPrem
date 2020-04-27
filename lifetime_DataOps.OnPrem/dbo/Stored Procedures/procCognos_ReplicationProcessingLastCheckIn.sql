
CREATE PROC [dbo].[procCognos_ReplicationProcessingLastCheckIn] 

AS
BEGIN 
SET XACT_ABORT ON
SET NOCOUNT ON

SELECT C.ClubName, 
       C.ClubCode, 
       MAX(MU.UsageDateTime) AS LastCheckIn, 
       MU.UsageDateTimeZone,
       Replace(Substring(convert(varchar,getdate(),100),1,6)+', '+Substring(convert(varchar,getdate(),100),8,10)+' '+Substring(convert(varchar,getdate(),100),18,2),'  ',' ') ReportRunDateTime
FROM vClub C
JOIN vMemberUsage MU
  ON MU.ClubID = C.ClubID
WHERE MU.UsageDateTime >= DATEADD(HH,-72,GETDATE())
GROUP BY C.ClubName, C.ClubCode, MU.UsageDateTimeZone


END
