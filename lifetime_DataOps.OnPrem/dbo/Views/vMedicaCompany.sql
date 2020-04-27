
CREATE VIEW dbo.vMedicaCompany AS 
SELECT MedicaCompanyID,MedicaCompanyCode,MedicaCompanyName,StartDate,EndDate,ValMedicaProgramID,IFRateOverride
FROM MMS.dbo.MedicaCompany WITH (NOLOCK)


