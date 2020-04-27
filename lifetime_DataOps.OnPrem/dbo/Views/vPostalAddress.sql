CREATE VIEW dbo.vPostalAddress AS 
SELECT PostalAddressID,AddressLine1,AddressLine2,City,Zip,ValStateID,ValCountryID,InsertedDateTime,UpdatedDateTime
FROM MMS.dbo.PostalAddress WITH(NOLOCK)
