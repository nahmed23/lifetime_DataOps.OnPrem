﻿CREATE VIEW dbo.vTranItemDiscount AS 
SELECT TranItemDiscountID,TranItemID,PricingDiscountID,AppliedDiscountAmount,InsertedDateTime,UpdatedDateTime,PromotionCode,ValDiscountReasonID
FROM MMS_Archive.dbo.TranItemDiscount WITH(NOLOCK)
