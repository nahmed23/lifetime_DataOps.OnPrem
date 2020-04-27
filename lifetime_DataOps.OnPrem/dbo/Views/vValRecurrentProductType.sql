CREATE VIEW dbo.vValRecurrentProductType AS 
SELECT ValRecurrentProductTypeID,Description,SortOrder
FROM MMS.dbo.ValRecurrentProductType WITH (NoLock)
