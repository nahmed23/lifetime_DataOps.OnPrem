


CREATE VIEW dbo.vContactPhone AS SELECT ContactPhoneID,ContactID,AreaCode,ValPhoneTypeID,Number 
FROM MMS.dbo.ContactPhone With (NOLOCK)


