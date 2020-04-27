CREATE VIEW dbo.vGuestVisit AS 
SELECT GuestVisitID,GuestID,ClubID,VisitDateTime,ValGuestAccessMethodID,MemberID,EmployeeID,Comment,PromotionCode
FROM MMS.dbo.GuestVisit WITH(NOLOCK)
