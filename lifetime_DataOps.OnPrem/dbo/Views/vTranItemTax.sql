





CREATE VIEW dbo.vTranItemTax
AS
SELECT TranItemTaxID, TranItemID, TaxRateID, TaxPercentage, ItemTaxAmount, ValTaxTypeID
FROM MMS_Archive.dbo.TranItemTax With (NOLOCK)





