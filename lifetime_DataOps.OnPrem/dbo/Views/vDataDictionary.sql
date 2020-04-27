CREATE VIEW dbo.vDataDictionary AS 
SELECT DataDictionaryID,TableName,ColumnName,Description
FROM MMS.dbo.DataDictionary With(NoLock)
