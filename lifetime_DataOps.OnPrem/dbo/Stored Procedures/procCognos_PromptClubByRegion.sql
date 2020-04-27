



CREATE PROCEDURE [dbo].[procCognos_PromptClubByRegion]

AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON


SELECT 
	Region.Description as MMSRegionDescription,
	Club.ClubID MMSClubID,
	Club.ClubName,
    Club.DisplayUIFlag,
    Club.ClubActivationDate,
    Club.DomainNamePrefix,
    Club.CRMDivisionCode,
	Club.ClubCode,
    Club.GLClubID,
	Club.ValPresaleID,
    Club.ValMemberActivityRegionID,
    CASE WHEN MemberActivityRegion.Description is NULL 
              THEN 'None Designated' 
         ELSE MemberActivityRegion.Description 
     END as MemberActivitiesRegionDescription,
    Region.ValRegionID,
    Club.ValPTRCLAreaID,
    CASE WHEN PTRCLArea.Description is NULL 
              THEN 'None Designated' 
         ELSE PTRCLArea.Description 
     END as PTRCLArea,
    Club.ValSalesAreaID,
    CASE WHEN SalesArea.Description is NULL
              THEN 'None Designated'
         --ELSE Substring(SalesArea.Description,10,(LEN(SalesArea.Description)-9)) 
		 ELSE SalesArea.Description
     END AS SalesArea,
	PreSale.Description PresaleDescription,
	IsNull(Club.ClubCode,'') + ' - ' + Club.ClubName ClubCode_ClubName,
	Club.ClubDeActivationDate

FROM vClub Club
JOIN vValRegion Region
  ON Region.ValRegionID = Club.ValRegionID
LEFT JOIN vValPreSale PreSale
  ON PreSale.ValPreSaleID = Club.ValPreSaleID
LEFT JOIN vValMemberActivityRegion MemberActivityRegion
  ON Club.ValMemberActivityRegionID = MemberActivityRegion.ValMemberActivityRegionID
LEFT JOIN vValPTRCLArea PTRCLArea 
  ON PTRCLArea.ValPTRCLAreaID = Club.ValPTRCLAreaID
LEFT JOIN vValSalesArea SalesArea
  ON SalesArea.ValSalesAreaID = Club.ValSalesAreaID
WHERE (Club.DisplayUIFlag = 1 or Club.ValPTRCLAreaID = 29)   ------ #29 = "Corp" and additionally returns Corporate Internal and E-Commerce Transactions "clubs" - needed for PT DSSR 4/22/15 srm


END




