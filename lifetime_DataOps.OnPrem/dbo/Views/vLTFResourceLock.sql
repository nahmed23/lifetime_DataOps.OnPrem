CREATE VIEW dbo.vLTFResourceLock AS 
SELECT LTFResourceLockID,LTFResourceID,ResourceLockTotal,InsertedDateTime,UpdatedDateTime
FROM MMS.dbo.LTFResourceLock WITH(NOLOCK)
