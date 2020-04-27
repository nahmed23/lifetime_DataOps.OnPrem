CREATE VIEW dbo.vLTFKey AS 
SELECT LTFKeyID,Identifier,Name,InsertedDateTime,UpdatedDateTime
FROM MMS.dbo.LTFKey WITH(NOLOCK)
