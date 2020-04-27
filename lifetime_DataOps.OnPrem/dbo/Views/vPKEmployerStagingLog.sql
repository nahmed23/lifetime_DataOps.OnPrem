


CREATE VIEW dbo.vPKEmployerStagingLog
AS
SELECT PKEmployerStagingID, EmployerName, AddressLine1, AddressLine2, City,
       ValStateID, Zip,ValCountryID, AreaCode, Number
FROM MMS.dbo.PKEmployerStagingLog


