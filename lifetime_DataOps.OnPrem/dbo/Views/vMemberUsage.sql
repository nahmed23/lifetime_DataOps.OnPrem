CREATE VIEW dbo.vMemberUsage AS 
SELECT MemberUsageID,ClubID,MemberID,UsageDateTime,UTCUsageDateTime,UsageDateTimeZone,InsertedDateTime,UpdatedDateTime,CheckinDelinquentFlag,DepartmentID,LTFKeyOwnerID
FROM MMS_Archive.dbo.MemberUsage WITH(NOLOCK)
