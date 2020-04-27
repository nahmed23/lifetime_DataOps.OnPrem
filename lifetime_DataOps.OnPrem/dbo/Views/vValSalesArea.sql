CREATE VIEW dbo.vValSalesArea AS 
SELECT ValSalesAreaID,Description,SortOrder
FROM MMS.dbo.ValSalesArea WITH(NOLOCK)
