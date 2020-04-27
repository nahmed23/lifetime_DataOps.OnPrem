CREATE VIEW dbo.vValCustomerType AS 
SELECT ValCustomerTypeID,Description,SortOrder
FROM MMS.dbo.ValCustomerType WITH(NOLOCK)
