


CREATE VIEW dbo.vPKEmployerStaging
AS
SELECT PKEmployerStagingID, EmployerName, AddressLine1, AddressLine2, City,
       ValStateID, Zip,ValCountryID, AreaCode, Number
FROM MMS.dbo.PKEmployerStaging


