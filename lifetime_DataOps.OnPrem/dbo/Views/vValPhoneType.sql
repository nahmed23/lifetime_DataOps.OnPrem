
CREATE VIEW dbo.vValPhoneType AS 
SELECT ValPhoneTypeID,Description,SortOrder
FROM MMS.dbo.ValPhoneType WITH (NoLock)

