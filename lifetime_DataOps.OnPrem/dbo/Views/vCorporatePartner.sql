CREATE VIEW dbo.vCorporatePartner AS 
SELECT CorporatePartnerID,PartnerName,PartnerIdentifier,ContactEmailAddress,RequestMemberCards
FROM MMS.dbo.CorporatePartner WITH(NOLOCK)
