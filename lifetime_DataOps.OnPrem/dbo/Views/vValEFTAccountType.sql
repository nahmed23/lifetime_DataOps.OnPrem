
CREATE VIEW dbo.vValEFTAccountType AS 
SELECT ValEFTAccountTypeID,Description,SortOrder
FROM MMS.dbo.ValEFTAccountType WITH (NoLock)

