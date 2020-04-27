CREATE VIEW dbo.vSalesforceRole AS 
SELECT SalesforceRoleID,SalesforceRole,ValEmployeeRoleID
FROM MMS.dbo.SalesforceRole WITH(NOLOCK)
