CREATE VIEW dbo.vCreditCardAddress AS 
SELECT CreditCardAddressID,CreditCardAccountID,InsertedDateTime,UpdatedDateTime,AddressLine1,AddressLine2,City,Zip,ValStateID,ValCountryID
FROM MMS.dbo.CreditCardAddress WITH(NOLOCK)
