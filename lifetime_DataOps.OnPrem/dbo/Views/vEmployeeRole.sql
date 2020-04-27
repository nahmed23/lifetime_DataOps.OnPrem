
CREATE VIEW [dbo].[vEmployeeRole] AS SELECT EmployeeRoleID,EmployeeID,ValEmployeeRoleID, PrimaryEmployeeRoleFlag
FROM MMS.dbo.EmployeeRole With (NOLOCK)
