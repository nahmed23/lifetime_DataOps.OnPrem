CREATE VIEW dbo.vProductPKOptions AS 
SELECT ProductPKOptionsID,ProductID,PKStartDate,PKEndDate,ValFirstMonthDuesTypeID,PKOptOutFlag,ActivationDeltaM,PKText
FROM MMS.dbo.ProductPKOptions WITH(NOLOCK)
