
CREATE VIEW dbo.vValServiceAccessCode AS 
SELECT ValServiceAccessCodeID,Description,SortOrder
FROM MMS.dbo.ValServiceAccessCode WITH (NoLock)

