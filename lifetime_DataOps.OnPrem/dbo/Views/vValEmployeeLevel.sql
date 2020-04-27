CREATE VIEW dbo.vValEmployeeLevel AS 
SELECT ValEmployeeLevelID,Description,SortOrder,InsertedDateTime,UpdatedDateTime
FROM MMS.dbo.ValEmployeeLevel WITH(NOLOCK)
