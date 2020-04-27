
CREATE VIEW [dbo].[vCreditCardAccountAudit] AS 
SELECT CreditCardAccountID,ExpirationDate,ValPaymentTypeID,BeginDateTime,EndDateTime,MaskedAccountNumber64,EncryptedAccountNumber
FROM MMS.dbo.CreditCardAccountAudit

