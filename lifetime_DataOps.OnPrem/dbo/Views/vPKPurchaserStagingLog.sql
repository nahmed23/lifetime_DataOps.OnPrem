


CREATE VIEW dbo.vPKPurchaserStagingLog
AS
SELECT PKPurchaserStagingID, FirstName, MiddleName, LastName, AddressLine1,
       AddressLine2, City, ValStateID, Zip, ValCountryID,AreaCode, Number
FROM MMS.dbo.PKPurchaserStagingLog


