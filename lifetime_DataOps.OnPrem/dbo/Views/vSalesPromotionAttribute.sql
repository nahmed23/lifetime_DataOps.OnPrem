﻿CREATE VIEW dbo.vSalesPromotionAttribute AS 
SELECT SalesPromotionAttributeID,SalesPromotionID,ValSalesPromotionAttributeID
FROM MMS.dbo.SalesPromotionAttribute WITH(NOLOCK)
