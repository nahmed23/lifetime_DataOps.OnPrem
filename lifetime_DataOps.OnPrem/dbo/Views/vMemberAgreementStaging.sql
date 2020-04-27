
CREATE VIEW [dbo].[vMemberAgreementStaging] AS 
SELECT MemberAgreementStagingID,MemberID,MemberShipID,AgreementID,ValContractTypeID,AgreementContentXML,ValAgreementActionID
FROM MMS.dbo.MemberAgreementStaging

