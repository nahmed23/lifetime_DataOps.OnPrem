CREATE VIEW dbo.vClubProductLevelPrice AS 
SELECT ClubProductLevelPriceID,ClubID,ProductID,ValEmployeeLevelID,Price,InsertedDateTime,UpdatedDateTime
FROM MMS.dbo.ClubProductLevelPrice WITH(NOLOCK)
