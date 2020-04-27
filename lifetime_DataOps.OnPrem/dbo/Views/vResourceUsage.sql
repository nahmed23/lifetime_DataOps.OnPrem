CREATE VIEW dbo.vResourceUsage AS 
SELECT ResourceUsageID,LTFResourceID,LTFKeyOwnerID,ValResourceUsageSourceTypeID,PartyID,UsageDateTime,UsageDateTimeZone,InsertedDateTime,UpdatedDateTime,ClubID
FROM MMS.dbo.ResourceUsage WITH(NOLOCK)
