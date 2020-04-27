CREATE VIEW dbo.vBankAddress AS 
SELECT BankAddressID,BankAccountID,ValAddressTypeID,AddressLine1,AddressLine2,City,Zip,ValCountryID,ValStateID,InsertedDateTime,UpdatedDateTime
FROM MMS.dbo.BankAddress WITH(NOLOCK)
