CREATE VIEW dbo.vValEmployeeRoleGroup AS 
SELECT ValEmployeeRoleGroupID,Description,SortOrder,InsertedDateTime,UpdatedDateTime
FROM MMS.dbo.ValEmployeeRoleGroup WITH(NOLOCK)
