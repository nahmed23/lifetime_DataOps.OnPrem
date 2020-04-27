
CREATE VIEW dbo.vMemberPhotoCaptureHistory AS 
SELECT MemberPhotoCaptureHistoryID,EmployeeID,MemberID,ClubID,PhotoCaptureDateTime,UTCPhotoCaptureDateTime,PhotoCaptureDateTimeZone
FROM MMS.dbo.MemberPhotoCaptureHistory WITH (NoLock)

