


CREATE VIEW dbo.vClubProductPKPrice
AS
SELECT ClubProductPKPriceID, ClubID, 
    ProductID, Price
FROM MMS.dbo.ClubProductPKPrice With (NOLOCK)



