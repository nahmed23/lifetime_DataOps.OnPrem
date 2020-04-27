CREATE VIEW dbo.vCreditCardUser AS 
SELECT CreditCardUserID,LTFEBPartyID,MemberID,CreditCardAccountID,CCUName,InsertedDateTime,UpdatedDateTime
FROM MMS.dbo.CreditCardUser WITH(NOLOCK)
