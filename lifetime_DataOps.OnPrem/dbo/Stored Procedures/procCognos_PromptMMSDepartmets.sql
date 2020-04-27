

-- Returns a result set of unique Department names

CREATE PROC [dbo].[procCognos_PromptMMSDepartmets]
AS
SET XACT_ABORT ON
SET NOCOUNT ON


SELECT DepartmentID, Description
  FROM dbo.vDepartment
ORDER BY Description


