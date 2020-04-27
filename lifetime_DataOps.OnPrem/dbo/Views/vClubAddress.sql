CREATE VIEW dbo.vClubAddress AS 
SELECT ClubAddressID,ClubID,AddressLine1,AddressLine2,City,ValAddressTypeID,Zip,InsertedDateTime,ValCountryID,ValStateID,UpdatedDateTime,Latitude,Longitude,MapCenterLatitude,MapCenterLongitude,MapZoomLevel,CancelEmail
FROM MMS.dbo.ClubAddress WITH(NOLOCK)
