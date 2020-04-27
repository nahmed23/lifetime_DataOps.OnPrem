CREATE VIEW dbo.vValLTFKeyType AS 
SELECT ValLTFKeyTypeID,Description,SortOrder,InsertedDateTime,UpdatedDateTime
FROM MMS.dbo.ValLTFKeyType WITH(NOLOCK)
