CREATE VIEW dbo.vDepartmentUnit AS 
SELECT DepartmentUnitID,DepartmentName,DepartmentHeadEmailAddress,InsertedDateTime,UpdatedDateTime,DisplayUIFlag
FROM MMS.dbo.DepartmentUnit WITH(NOLOCK)
