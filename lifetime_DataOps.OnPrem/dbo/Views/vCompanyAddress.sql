
CREATE VIEW dbo.vCompanyAddress AS 
SELECT CompanyAddressID,CompanyID,AddressLine1,AddressLine2,City,ValAddressTypeID,Zip,ValStateID,ValCountryID
FROM MMS.dbo.CompanyAddress WITH (NoLock)

