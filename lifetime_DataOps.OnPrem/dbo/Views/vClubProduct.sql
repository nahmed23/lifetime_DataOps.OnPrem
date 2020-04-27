
CREATE VIEW dbo.vClubProduct AS 
SELECT ClubProductID,ClubID,ProductID,Price,ValCommissionableID,SoldInPK
FROM MMS.dbo.ClubProduct WITH (NoLock)

