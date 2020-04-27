CREATE VIEW dbo.vClubProductSecuritySequence AS 
SELECT Sequence
FROM MMS.dbo.ClubProductSecuritySequence WITH(NOLOCK)
