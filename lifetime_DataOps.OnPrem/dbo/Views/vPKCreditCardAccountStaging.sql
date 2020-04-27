

CREATE VIEW [dbo].[vPKCreditCardAccountStaging] AS 
SELECT PKCreditCardAccountStagingID,AccountNumber,Name,ExpirationDate,ValPaymentTypeID,PKMembershipStagingID,LTFCreditCardAccountFlag,AllowCardOnFileTranFlag,ManualEntryFlag,InsertedDateTime,MaskedAccountNumber,MaskedAccountNumber64, CAST(NULL AS VARBINARY(48)) AS EncryptedAccountNumber,Token
FROM MMS.dbo.PKCreditCardAccountStaging WITH(NOLOCK)

