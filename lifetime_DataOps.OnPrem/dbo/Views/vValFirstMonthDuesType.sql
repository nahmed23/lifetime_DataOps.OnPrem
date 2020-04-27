CREATE VIEW dbo.vValFirstMonthDuesType AS 
SELECT ValFirstMonthDuesTypeID,Description,SortOrder
FROM MMS.dbo.ValFirstMonthDuesType WITH(NOLOCK)
