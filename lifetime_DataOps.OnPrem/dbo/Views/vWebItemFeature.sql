CREATE VIEW dbo.vWebItemFeature AS 
SELECT WebItemFeatureID,WebItemID,FeatureType,FeatureValue,FeatureAlternateID
FROM MMS_Archive.dbo.WebItemFeature WITH(NOLOCK)
