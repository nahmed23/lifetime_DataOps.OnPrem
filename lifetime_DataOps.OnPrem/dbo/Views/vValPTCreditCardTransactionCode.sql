﻿CREATE VIEW dbo.vValPTCreditCardTransactionCode AS 
SELECT ValPTCreditCardTransactionCodeID,Description,SortOrder,TransactionCode
FROM MMS.dbo.ValPTCreditCardTransactionCode WITH(NOLOCK)
