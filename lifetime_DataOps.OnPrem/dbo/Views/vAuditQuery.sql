
CREATE VIEW dbo.vAuditQuery
AS
SELECT      Application , Document, Section, Username , Parameters , Rows, StartDate , EndDate 
FROM         dbo.AuditQuery
