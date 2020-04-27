﻿CREATE VIEW dbo.vPKCreditCardAccountStagingLog AS 
SELECT PKCreditCardAccountStagingID,AccountNumber,Name,ExpirationDate,ValPaymentTypeID,PKMembershipStagingID,LTFCreditCardAccountFlag,AllowCardOnFileTranFlag,ManualEntryFlag,UpdatedDateTime,MaskedAccountNumber,MaskedAccountNumber64
FROM MMS.dbo.PKCreditCardAccountStagingLog WITH(NOLOCK)
