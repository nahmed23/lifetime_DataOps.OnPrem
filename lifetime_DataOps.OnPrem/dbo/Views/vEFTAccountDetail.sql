

CREATE VIEW [dbo].[vEFTAccountDetail] AS 
SELECT E.MembershipID, NULL ExpirationDate,B.AccountNumber,
       B.Name,B.PreNotifyFlag,B.RoutingNumber,B.ValPaymentTypeID,
       B.BankName, B.MaskedAccountNumber, NULL EncryptedAccountNumber
FROM vEFTAccount E
       JOIN vBankAccount B  ON E.BankAccountID = B.BankAccountID
WHERE E.BankAccountFlag = 1
UNION
SELECT E.MembershipID, CC.ExpirationDate,NULL AccountNumber,
       CC.Name,NULL PreNotifyFlag,NULL RoutingNumber,CC.ValPaymentTypeID,
       NULL BankName, CC.MaskedAccountNumber, CC.EncryptedAccountNumber
FROM vEFTAccount E
       JOIN vCreditCardAccount CC  ON E.CreditCardAccountID = CC.CreditCardAccountID
WHERE E.BankAccountFlag = 0
