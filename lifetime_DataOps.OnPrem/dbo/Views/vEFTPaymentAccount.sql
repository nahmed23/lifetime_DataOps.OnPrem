

CREATE VIEW dbo.vEFTPaymentAccount AS 
SELECT M.MemberID,E.MembershipID, NULL ExpirationDate,B.AccountNumber,
       B.Name,B.PreNotifyFlag,B.RoutingNumber,B.ValPaymentTypeID, VP.ValEFTAccountTypeID,
       B.BankName,MB.EFTAmount,MS.ValEFTOptionID,C.ValStatementTypeID, C.ChargeToAccountFlag,
       MA.Zip,NULL MaskedAccountNumber,NULL EncryptedAccountNumber,MS.ClubID
FROM vEFTAccount E 
       JOIN vMember M ON E.MembershipID = M.MembershipID AND M.ValMemberTypeID = 1
       JOIN vMembershipBalance MB ON E.MembershipID = MB.MembershipID
       JOIN vMembershipAddress MA ON E.MembershipID = MA.MembershipID
       JOIN vMembership MS ON E.MembershipID = MS.MembershipID 
       JOIN vClub C ON MS.ClubID = C.ClubID
       JOIN vBankAccount B ON E.BankAccountID = B.BankAccountID
       JOIN vValPaymentType VP ON B.ValPaymentTypeID = VP.ValPaymentTypeID
WHERE E.BankAccountFlag = 1
UNION
SELECT M.MemberID,E.MembershipID, CC.ExpirationDate,NULL AccountNumber,
       CC.Name,NULL PreNotifyFlag,NULL RoutingNumber,CC.ValPaymentTypeID,VP.ValEFTAccountTypeID,
       NULL BankName,MB.EFTAmount,MS.ValEFTOptionID,C.ValStatementTypeID, C.ChargeToAccountFlag,
       MA.Zip,CC.MaskedAccountNumber,CC.EncryptedAccountNumber,MS.ClubID
FROM vEFTAccount E 
       JOIN vMember M ON E.MembershipID = M.MembershipID AND M.ValMemberTypeID = 1
       JOIN vMembershipBalance MB ON E.MembershipID = MB.MembershipID
       JOIN vMembership MS ON E.MembershipID = MS.MembershipID
       JOIN vClub C ON MS.ClubID = C.ClubID
       JOIN vCreditCardAccount CC on E.CreditCardAccountID = CC.CreditCardAccountID
       JOIN vValPaymentType VP ON CC.ValPaymentTypeID = VP.ValPaymentTypeID
       LEFT JOIN vMembershipAddress MA ON E.MembershipID = MA.MembershipID
WHERE E.BankAccountFlag = 0


