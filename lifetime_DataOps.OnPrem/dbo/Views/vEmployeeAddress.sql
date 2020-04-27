
CREATE VIEW dbo.vEmployeeAddress AS 
SELECT EmployeeAddressID,EmployeeID,AddressLine1,AddressLine2,City,ValAddressTypeID,Zip,ValCountryID,ValStateID
FROM MMS.dbo.EmployeeAddress WITH (NoLock)

