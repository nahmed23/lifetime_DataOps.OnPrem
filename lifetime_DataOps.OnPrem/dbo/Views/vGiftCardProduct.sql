﻿CREATE VIEW dbo.vGiftCardProduct AS 
SELECT GiftCardProductID,ProductID,ComplimentaryFlag,MaximumQuantity,DefaultIssuanceAmount,MaximumIssuanceAmount,MinimumIssuanceAmount
FROM MMS.dbo.GiftCardProduct WITH(NOLOCK)
