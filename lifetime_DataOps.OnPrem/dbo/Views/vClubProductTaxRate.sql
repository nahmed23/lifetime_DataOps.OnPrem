


CREATE VIEW dbo.vClubProductTaxRate
AS
SELECT ClubProductTaxRateID, ClubID, ProductID, TaxRateID,StartDate, EndDate
FROM MMS.dbo.ClubProductTaxRate With (NOLOCK)


