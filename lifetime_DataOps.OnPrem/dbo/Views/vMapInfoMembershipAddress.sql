

CREATE VIEW [dbo].[vMapInfoMembershipAddress]
AS
SELECT     MapInfoMembershipAddressID, MembershipID, AddressLine1, AddressLine2, City, StateAbbreviation, Zip, Latitude, Longitude, GeoResults, AccessMembershipFlag, CheckInLevel
FROM         dbo.MapInfoMembershipAddress

