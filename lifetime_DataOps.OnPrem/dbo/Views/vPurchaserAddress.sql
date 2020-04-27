
CREATE VIEW dbo.vPurchaserAddress AS 
SELECT PurchaserAddressID,PurchaserID,AddressLine1,AddressLine2,City,ValAddressTypeID,Zip,ValCountryID,ValStateID
FROM MMS.dbo.PurchaserAddress WITH (NoLock)

