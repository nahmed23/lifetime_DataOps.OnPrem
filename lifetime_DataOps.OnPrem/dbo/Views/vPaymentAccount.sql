
CREATE VIEW [dbo].[vPaymentAccount] AS 
SELECT PaymentAccountID,PaymentID,ExpirationDate,AccountNumber,Name,InsertedDateTime,RoutingNumber,BankName, CAST(NULL AS VARBINARY(48)) AS EncryptedAccountNumber,  CAST(NULL AS VARCHAR(17)) AS MaskedAccountNumber,Token
FROM MMS_Archive.dbo.PaymentAccount WITH(NOLOCK)

