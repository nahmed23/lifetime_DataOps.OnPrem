

CREATE VIEW dbo.vChildCenterUsageException
AS
SELECT ChildCenterUsageExceptionID,ChildCenterUsageID,EmployeeID,ValChildCenterUsageExceptionID
FROM MMS.dbo.ChildCenterUsageException With (NOLOCK)

