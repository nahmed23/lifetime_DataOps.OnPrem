


CREATE VIEW dbo.vDSSRSportsNonAccessSummary
AS
SELECT     DSSRSportsNonAccessSummaryID, MembershipID, ActivationDate, ExpirationDate, CancellationRequestDate, MemberID, FirstName, LastName, 
                      ClubID, ClubName,InsertedDateTime, Today_Flag, SignOnDate, TerminationDate
FROM         dbo.DSSRSportsNonAccessSummary WITH (NoLock)




