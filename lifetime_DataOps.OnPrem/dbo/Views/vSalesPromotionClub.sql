CREATE VIEW dbo.vSalesPromotionClub AS 
SELECT SalesPromotionClubID,SalesPromotionID,ClubID
FROM MMS.dbo.SalesPromotionClub WITH(NOLOCK)
