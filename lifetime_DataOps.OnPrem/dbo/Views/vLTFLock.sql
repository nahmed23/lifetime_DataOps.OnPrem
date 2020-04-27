CREATE VIEW dbo.vLTFLock AS 
SELECT LTFLockID,Name,InsertedDateTime,UpdatedDateTime
FROM MMS.dbo.LTFLock WITH(NOLOCK)
