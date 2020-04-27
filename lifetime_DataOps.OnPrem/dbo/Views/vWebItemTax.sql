CREATE VIEW dbo.vWebItemTax AS 
SELECT WebItemTaxID,WebItemID,TaxRateID,TaxPercentage,TaxAmount,ValTaxTypeID
FROM MMS_Archive.dbo.WebItemTax WITH(NOLOCK)
