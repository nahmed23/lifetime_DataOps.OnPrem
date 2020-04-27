
CREATE VIEW [dbo].[vPromotion] AS 
SELECT PromotionID,PromotionName,PromotionCode,PromotionOwner,StartDate,EndDate,EnrollmentDiscPercentage,InitiationFee,CompanyID,ValPromotionTypeID,DollarDiscount,AdminFee
FROM MMS.dbo.Promotion WITH(NOLOCK)
