CREATE VIEW dbo.vLTFLockKey AS 
SELECT LTFLockKeyID,LTFLockID,LTFKeyID,InsertedDateTime,UpdatedDateTime
FROM MMS.dbo.LTFLockKey WITH(NOLOCK)
