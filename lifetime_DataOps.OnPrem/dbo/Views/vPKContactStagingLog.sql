
CREATE VIEW dbo.vPKContactStagingLog
AS
SELECT PKContactStagingID, PKMembershipStagingID, FirstName, MiddleName, LastName, AreaCode, Number,
       ValContactTypeID
FROM MMS.dbo.PKContactStagingLog

