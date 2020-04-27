
CREATE VIEW dbo.vValTaxType AS 
SELECT ValTaxTypeID,Description,SortOrder
FROM MMS.dbo.ValTaxType WITH (NoLock)

