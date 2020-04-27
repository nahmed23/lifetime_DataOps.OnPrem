CREATE VIEW dbo.vGuestCount AS 
SELECT GuestCountID,ClubID,GuestCountDate,MemberCount,NonMemberCount,MemberChildCount,NonMemberChildCount
FROM MMS.dbo.GuestCount WITH(NOLOCK)
