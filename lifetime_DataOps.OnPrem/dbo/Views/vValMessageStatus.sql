
CREATE VIEW dbo.vValMessageStatus AS 
SELECT ValMessageStatusID,Description,SortOrder
FROM MMS.dbo.ValMessageStatus WITH (NoLock)

