﻿CREATE VIEW dbo.vWebItemDiscount AS 
SELECT WebItemDiscountID,WebItemID,AppliedDiscountAmount,PricingDiscountID,InsertedDateTime,UpdatedDateTime,PromotionCode
FROM MMS_Archive.dbo.WebItemDiscount WITH(NOLOCK)
