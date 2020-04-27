
CREATE VIEW dbo.vContactAddress AS 
SELECT ContactAddressID,ContactID,AddressLine1,AddressLine2,City,ValAddressTypeID,Zip,ValCountryID,ValStateID
FROM MMS.dbo.ContactAddress WITH (NoLock)

