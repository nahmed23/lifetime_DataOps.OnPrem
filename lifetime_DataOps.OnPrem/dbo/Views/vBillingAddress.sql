
CREATE VIEW dbo.vBillingAddress AS 
SELECT BillingAddressID,MembershipID,CompanyName,FirstName,MiddleInt,LastName,AddressLine1,AddressLine2,City,ValAddressTypeID,Zip,ValCountryID,ValStateID
FROM MMS.dbo.BillingAddress WITH (NoLock)

