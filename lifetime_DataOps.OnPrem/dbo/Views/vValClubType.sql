
CREATE VIEW dbo.vValClubType AS 
SELECT ValClubTypeID,Description,SortOrder
FROM MMS.dbo.ValClubType WITH (NoLock)

