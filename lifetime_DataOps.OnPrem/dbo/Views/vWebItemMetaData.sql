CREATE VIEW dbo.vWebItemMetaData AS 
SELECT WebItemMetaDataID,WebItemID,MetaName,MetaValue,InsertedDateTime,UpdatedDateTime
FROM MMS_Archive.dbo.WebItemMetaData WITH(NOLOCK)
