﻿CREATE VIEW dbo.vQualifiedSalesPromotionEmailTemplate AS 
SELECT QualifiedSalesPromotionEmailTemplateID,QualifiedSalesPromotionID,ValEmailTemplateTypeID,InsertedDateTime,UpdatedDateTime,EmailKey
FROM MMS.dbo.QualifiedSalesPromotionEmailTemplate WITH(NOLOCK)
