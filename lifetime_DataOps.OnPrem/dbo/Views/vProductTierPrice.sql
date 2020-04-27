CREATE VIEW dbo.vProductTierPrice AS 
SELECT ProductTierPriceID,ProductTierID,Price,ValMembershipTypeGroupID,InsertedDateTime,UpdatedDateTime,ValCardLevelID
FROM MMS.dbo.ProductTierPrice WITH(NOLOCK)
