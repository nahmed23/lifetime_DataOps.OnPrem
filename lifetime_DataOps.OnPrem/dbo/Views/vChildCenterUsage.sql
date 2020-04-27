


CREATE VIEW dbo.vChildCenterUsage
AS
SELECT ChildCenterUsageID,MemberID,ClubID,CheckInMemberID,CheckInDateTime,CheckOutMemberID,
              CheckOutDateTime,UTCCheckInDateTime,CheckInDateTimeZone, UTCCheckOutDateTime,CheckOutDateTimeZone
FROM MMS_Archive.dbo.ChildCenterUsage With (NOLOCK)


