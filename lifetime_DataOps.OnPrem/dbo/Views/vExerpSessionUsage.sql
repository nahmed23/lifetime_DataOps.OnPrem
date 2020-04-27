CREATE VIEW dbo.vExerpSessionUsage AS 
SELECT ExerpSessionUsageID,UsageID,ExternalPackageID,NumberOfClips,InsertedDateTime,UpdatedDateTime
FROM MMS_Archive.dbo.ExerpSessionUsage WITH(NOLOCK)
