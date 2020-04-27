
CREATE VIEW [dbo].[vCognos_ClubByMMSRegion] AS
SELECT 
	CASE WHEN DisplayUIFlag = 0 OR Region.Description IS NULL
		 THEN 'None Designated'
		 ELSE Region.Description
	END MMSRegionDescription,
	Club.ClubName,
	Club.ClubCode,
	Club.ClubID MMSClubID,
	Club.ValPresaleID,
	PreSale.Description PresaleDescription,
	Club.ClubCode + ' – ' + Club.ClubName ClubCode_ClubName,
    Club.DisplayUIFlag
FROM vClub Club
JOIN vValRegion Region
  ON Region.ValRegionID = Club.ValRegionID
LEFT JOIN vValPreSale PreSale
  ON PreSale.ValPreSaleID = Club.ValPreSaleID
