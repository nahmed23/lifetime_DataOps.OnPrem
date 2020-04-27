

CREATE PROC [dbo].[procCognos_PromptMMSDepartmentsWithPackageProducts] 

AS
BEGIN 
SET XACT_ABORT ON
SET NOCOUNT ON

SELECT DISTINCT Department.DepartmentID, Department.Description
FROM vDepartment Department
JOIN vProduct Product ON Department.DepartmentID = Product.DepartmentID
WHERE Product.PackageProductFlag = 1
ORDER BY Department.Description ASC

END


