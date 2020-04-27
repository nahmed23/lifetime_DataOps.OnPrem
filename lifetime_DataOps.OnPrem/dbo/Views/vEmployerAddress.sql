
CREATE VIEW dbo.vEmployerAddress AS 
SELECT EmployerAddressID,EmployerID,AddressLine1,AddressLine2,City,ValAddressTypeID,Zip,ValCountryID,ValStateID
FROM MMS.dbo.EmployerAddress WITH (NoLock)

