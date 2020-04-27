CREATE VIEW dbo.vEFTAccountProduct AS 
SELECT EFTAccountProductID,MembershipID,CreditCardAccountID,InsertedDateTime,UpdatedDateTime
FROM MMS_Archive.dbo.EFTAccountProduct WITH(NOLOCK)
