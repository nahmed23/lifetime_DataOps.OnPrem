CREATE VIEW dbo.vDeletedData AS 
SELECT DeletedDataID,TableName,PrimaryKeyID,DeletedDateTime
FROM MMS.dbo.DeletedData WITH(NOLOCK)
