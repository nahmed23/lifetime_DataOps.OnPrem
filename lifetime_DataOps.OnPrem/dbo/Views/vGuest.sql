CREATE VIEW dbo.vGuest AS 
SELECT GuestID,CardNumber,FirstName,MiddleName,LastName,AddressLine1,AddressLine2,City,State,ZIP,InsertedDateTime,UpdatedDateTime,MaskedPersonalID
FROM MMS.dbo.Guest WITH(NOLOCK)
