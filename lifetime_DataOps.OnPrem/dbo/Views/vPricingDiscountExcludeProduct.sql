﻿CREATE VIEW dbo.vPricingDiscountExcludeProduct AS 
SELECT PricingDiscountExcludeProductID,PricingDiscountID,ExcludeProductID
FROM MMS.dbo.PricingDiscountExcludeProduct WITH(NOLOCK)