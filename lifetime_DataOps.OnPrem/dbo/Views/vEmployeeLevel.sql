CREATE VIEW dbo.vEmployeeLevel AS 
SELECT EmployeeLevelID,EmployeeID,ValEmployeeLevelTypeID,ValEmployeeLevelID,InsertedDateTime,UpdatedDateTime
FROM MMS.dbo.EmployeeLevel WITH(NOLOCK)
