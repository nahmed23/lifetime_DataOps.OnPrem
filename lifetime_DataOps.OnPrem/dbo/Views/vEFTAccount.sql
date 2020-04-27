
CREATE VIEW dbo.vEFTAccount AS 
SELECT EFTAccountID,BankAccountID,MembershipID,CreditCardAccountID,BankAccountFlag
FROM MMS.dbo.EFTAccount WITH (NoLock)

