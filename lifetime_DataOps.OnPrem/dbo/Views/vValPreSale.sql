
CREATE VIEW dbo.vValPreSale AS 
SELECT ValPreSaleID,Description,SortOrder
FROM MMS.dbo.ValPreSale WITH (NoLock)

