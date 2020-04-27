CREATE VIEW dbo.vLTFKeyType AS 
SELECT LTFKeyTypeID,LTFKeyID,ValLTFKeyTypeID,InsertedDateTime,UpdatedDateTime
FROM MMS.dbo.LTFKeyType WITH(NOLOCK)
