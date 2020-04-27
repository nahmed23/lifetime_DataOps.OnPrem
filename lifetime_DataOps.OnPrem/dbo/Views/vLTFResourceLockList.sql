CREATE VIEW dbo.vLTFResourceLockList AS 
SELECT LTFResourceLockListID,LTFResourceLockID,LTFLockID,ResourceLockNumber,InsertedDateTime,UpdatedDateTime
FROM MMS.dbo.LTFResourceLockList WITH(NOLOCK)
