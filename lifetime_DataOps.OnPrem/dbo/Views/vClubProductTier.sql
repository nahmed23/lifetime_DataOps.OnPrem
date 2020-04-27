CREATE VIEW dbo.vClubProductTier AS 
SELECT ClubProductTierID,ClubID,ProductTierID,EffectiveFromDateTime,EffectiveThruDateTime,InsertedDateTime,UpdatedDateTime
FROM MMS.dbo.ClubProductTier WITH(NOLOCK)
