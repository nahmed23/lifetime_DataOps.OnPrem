
CREATE VIEW dbo.vValAddressType AS 
SELECT ValAddressTypeID,Description,SortOrder
FROM MMS.dbo.ValAddressType WITH (NoLock)

