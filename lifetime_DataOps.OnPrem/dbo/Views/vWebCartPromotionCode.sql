CREATE VIEW dbo.vWebCartPromotionCode AS 
SELECT WebCartPromotionCodeID,WebCartID,PromotionCode,InsertedDateTime,UpdatedDateTime
FROM MMS.dbo.WebCartPromotionCode WITH(NOLOCK)
