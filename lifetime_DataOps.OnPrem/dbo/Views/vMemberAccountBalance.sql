﻿CREATE VIEW dbo.vMemberAccountBalance AS 
SELECT MemberAccountBalanceID,CreditCardUserID,CurrentBalance,EFTAmount,CommitedBalance,InsertedDateTime,UpdatedDateTime
FROM MMS.dbo.MemberAccountBalance WITH(NOLOCK)
