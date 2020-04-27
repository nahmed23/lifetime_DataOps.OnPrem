CREATE VIEW dbo.vEmployeeRoleGroup AS 
SELECT EmployeeRoleGroupID,ValEmployeeRoleGroupID,ValEmployeeRoleID,InsertedDateTime,UpdatedDateTime
FROM MMS.dbo.EmployeeRoleGroup WITH(NOLOCK)
