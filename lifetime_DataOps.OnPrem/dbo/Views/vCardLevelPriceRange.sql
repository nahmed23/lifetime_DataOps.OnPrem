CREATE VIEW dbo.vCardLevelPriceRange AS 
SELECT CardLevelPriceRangeID,ValCardLevelID,ProductID,StartingPrice,EndingPrice,InsertedDateTime,UpdatedDateTime
FROM MMS.dbo.CardLevelPriceRange WITH(NOLOCK)
