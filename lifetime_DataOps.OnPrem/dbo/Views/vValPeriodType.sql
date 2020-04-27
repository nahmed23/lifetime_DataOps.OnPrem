CREATE VIEW dbo.vValPeriodType AS 
SELECT ValPeriodTypeID,Description,SortOrder
FROM MMS.dbo.ValPeriodType WITH(NOLOCK)
