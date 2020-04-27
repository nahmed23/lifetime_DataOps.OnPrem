


CREATE VIEW dbo.vPKPurchaserStaging
AS
SELECT PKPurchaserStagingID, FirstName, MiddleName, LastName, AddressLine1,
       AddressLine2, City, ValStateID, Zip, ValCountryID,AreaCode, Number
FROM MMS.dbo.PKPurchaserStaging


