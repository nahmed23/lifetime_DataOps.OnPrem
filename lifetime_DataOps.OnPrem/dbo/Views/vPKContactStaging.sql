

CREATE VIEW dbo.vPKContactStaging
AS
SELECT PKContactStagingID, PKMembershipStagingID, FirstName, MiddleName, LastName, AreaCode, Number,
       ValContactTypeID
FROM MMS.dbo.PKContactStaging

