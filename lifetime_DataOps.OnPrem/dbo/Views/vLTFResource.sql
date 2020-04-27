CREATE VIEW dbo.vLTFResource AS 
SELECT LTFResourceID,Identifier,Name,ValResourceTypeID,InsertedDateTime,UpdatedDateTime
FROM MMS.dbo.LTFResource WITH(NOLOCK)
