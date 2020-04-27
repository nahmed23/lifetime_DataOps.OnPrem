
CREATE VIEW dbo.vPromotionClub AS 
SELECT PromotionClubID,ClubID,PromotionID
FROM MMS.dbo.PromotionClub WITH(NOLOCK)

