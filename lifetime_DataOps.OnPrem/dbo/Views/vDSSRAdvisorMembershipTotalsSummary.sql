


CREATE VIEW dbo.vDSSRAdvisorMembershipTotalsSummary
AS
SELECT     DSSRAdvisorMembershipTotalsSummaryID, MembershipCount, AdvisorFirstName, AdvisorLastName, ClubID, ClubName,DomainNamePrefix ,ValTerminationReasonID, 
                      ExpirationDate,AdvisorEmployeeID,InsertedDateTime
FROM         dbo.DSSRAdvisorMembershipTotalsSummary WITH (NoLock)




