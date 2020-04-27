
CREATE VIEW dbo.vValMessageSeverity AS 
SELECT ValMessageSeverityID,Description,SortOrder,SeverityLevel
FROM MMS.dbo.ValMessageSeverity WITH (NoLock)

