CREATE VIEW dbo.vValEmployeeRole AS 
SELECT ValEmployeeRoleID,LTUPositionID,Description,SortOrder,DepartmentID,CommissionableFlag,InsertedDateTime,UpdatedDateTime,HRJobCode,CompanyInsiderType
FROM MMS.dbo.ValEmployeeRole WITH(NOLOCK)
