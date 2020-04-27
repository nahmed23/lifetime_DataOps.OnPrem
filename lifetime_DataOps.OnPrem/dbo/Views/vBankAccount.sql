CREATE VIEW dbo.vBankAccount AS 
SELECT BankAccountID,MembershipID,AccountNumber,Name,PreNotifyFlag,RoutingNumber,ValPaymentTypeID,InsertedDateTime,BankName,UpdatedDateTime,MaskedAccountNumber
FROM MMS.dbo.BankAccount WITH(NOLOCK)
