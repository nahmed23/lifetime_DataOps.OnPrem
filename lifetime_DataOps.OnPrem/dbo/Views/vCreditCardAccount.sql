
CREATE VIEW [dbo].[vCreditCardAccount] AS 
SELECT CreditCardAccountID,AccountNumber,Name,ExpirationDate,ValPaymentTypeID,MembershipID,ActiveFlag,LTFCreditCardAccountFlag,InsertedDateTime,MaskedAccountNumber,UpdatedDateTime,MaskedAccountNumber64, CAST(NULL AS VARBINARY(48)) AS EncryptedAccountNumber,Token
FROM MMS.dbo.CreditCardAccount WITH(NOLOCK)

