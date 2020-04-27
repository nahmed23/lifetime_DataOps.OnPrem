


CREATE VIEW dbo.vMembershipTypeClubAgreement
AS
SELECT MembershipTypeClubAgreementID, ClubID, MembershipTypeID, AgreementID
FROM MMS.dbo.MembershipTypeClubAgreement With (NOLOCK)


