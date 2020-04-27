
CREATE VIEW dbo.vValTranType AS 
SELECT ValTranTypeID,Description,SortOrder
FROM MMS.dbo.ValTranType WITH (NoLock)

