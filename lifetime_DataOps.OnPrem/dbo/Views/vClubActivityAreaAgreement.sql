CREATE VIEW dbo.vClubActivityAreaAgreement AS 
SELECT ClubActivityAreaAgreementID,ClubID,ValActivityAreaID,AgreementID,ExpirationMonths
FROM MMS.dbo.ClubActivityAreaAgreement WITH(NOLOCK)
