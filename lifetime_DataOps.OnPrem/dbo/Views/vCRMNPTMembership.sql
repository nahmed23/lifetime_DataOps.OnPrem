CREATE VIEW dbo.vCRMNPTMembership AS 
SELECT CRMNPTMembershipID,MembershipID,CRMNPTCaseID,CRMNPTCaseCreatedDate,InsertedDateTime,UpdatedDateTime
FROM MMS.dbo.CRMNPTMembership WITH(NOLOCK)
