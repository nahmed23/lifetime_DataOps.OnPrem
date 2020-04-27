

CREATE VIEW dbo.vMembershipAddress AS 
SELECT MembershipAddressID,MembershipID,AddressLine1,AddressLine2,City,ValAddressTypeID,Zip,ValCountryID,ValStateID,InsertedDateTime,UpdatedDateTime
FROM MMS.dbo.MembershipAddress WITH (NoLock)


