
CREATE VIEW dbo.vValEFTOption AS 
SELECT ValEFTOptionID,Description,SortOrder
FROM MMS.dbo.ValEFTOption WITH (NoLock)

