﻿CREATE VIEW dbo.vSalesPromotion AS 
SELECT SalesPromotionID,EffectiveFromDateTime,EffectiveThruDateTime,DisplayText,ReceiptText,ValSalesPromotionTypeID,AvailableForAllSalesChannelsFlag,AvailableForAllClubsFlag,AvailableForAllCustomersFlag,InsertedDateTime,UpdatedDateTime,PromotionOwnerEmployeeID,PromotionCodeUsageLimit,PromotionCodeRequiredFlag,PromotionCodeIssuerCreateLimit,PromotionCodeOverallCreateLimit,CompanyID,ExcludeMyHealthCheckFlag,ValRevenueReportingCategoryID,ValSalesReportingCategoryID,ExcludeFromAttritionReportingFlag
FROM MMS.dbo.SalesPromotion WITH(NOLOCK)
