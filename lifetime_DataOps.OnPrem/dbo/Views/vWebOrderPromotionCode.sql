CREATE VIEW dbo.vWebOrderPromotionCode AS 
SELECT WebOrderPromotionCodeID,WebOrderID,PromotionCode,InsertedDateTime,UpdatedDateTime
FROM MMS_Archive.dbo.WebOrderPromotionCode WITH(NOLOCK)
