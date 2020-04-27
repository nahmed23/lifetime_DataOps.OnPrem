CREATE VIEW dbo.vLTFResourceKey AS 
SELECT LTFResourceKeyID,LTFResourceID,LTFKeyID,InsertedDateTime,UpdatedDateTime
FROM MMS.dbo.LTFResourceKey WITH(NOLOCK)
