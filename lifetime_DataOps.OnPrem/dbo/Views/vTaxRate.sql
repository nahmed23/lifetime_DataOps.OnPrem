


CREATE VIEW dbo.vTaxRate
AS
SELECT TaxRateID, ValTaxTypeID, TaxPercentage
FROM MMS.dbo.TaxRate With (NOLOCK)


