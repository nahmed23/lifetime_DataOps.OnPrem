
CREATE VIEW dbo.vValEFTType AS 
SELECT ValEFTTypeID,Description,SortOrder
FROM MMS.dbo.ValEFTType WITH (NoLock)

