
CREATE VIEW [dbo].[vCognos_ReplicationProcessing_LastCheckin]
AS
SELECT c.ClubName, 
       c.ClubCode, 
       MAX(mu.UsageDateTime) AS LastCheckIn, 
       mu.UsageDateTimeZone
FROM vClub c
JOIN vMemberUsage mu
  ON mu.ClubID = c.ClubID
WHERE mu.UsageDateTime >= DATEADD(HH,-72,GETDATE())
GROUP BY c.ClubName, c.ClubCode, mu.UsageDateTimeZone
