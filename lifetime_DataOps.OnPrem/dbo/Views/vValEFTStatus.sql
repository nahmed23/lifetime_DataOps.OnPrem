
CREATE VIEW dbo.vValEFTStatus AS 
SELECT ValEFTStatusID,Description,SortOrder
FROM MMS.dbo.ValEFTStatus WITH (NoLock)

