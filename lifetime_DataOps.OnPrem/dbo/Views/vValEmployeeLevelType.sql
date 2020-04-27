CREATE VIEW dbo.vValEmployeeLevelType AS 
SELECT ValEmployeeLevelTypeID,Description,SortOrder,InsertedDateTime,UpdatedDateTime
FROM MMS.dbo.ValEmployeeLevelType WITH(NOLOCK)
