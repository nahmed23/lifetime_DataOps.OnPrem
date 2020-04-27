CREATE VIEW dbo.vReplicationTest AS 
SELECT ReplicationTestID,ReplicationDateTime
FROM MMS.dbo.ReplicationTest WITH(NOLOCK)
