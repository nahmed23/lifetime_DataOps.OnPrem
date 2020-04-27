

CREATE VIEW dbo.vClubSelect
	(ClubID
	,ValRegionID
	,ClubName
	,RegionName
	)
AS  
SELECT 0
      ,0
      ," < Select Club > " 
      ," < Select Region > "
UNION
SELECT vClub.ClubID
      ,vClub.ValRegionID
      ,vClub.ClubName
      ,ValRegion.Description
FROM dbo.vClub 
    ,MMS.dbo.ValRegion ValRegion
WHERE vClub.ValRegionID = ValRegion.ValRegionID



