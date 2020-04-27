
CREATE VIEW dbo.vPKProductOverrideStagingLog
AS
SELECT     PKProductOverrideStagingID, PKMembershipStagingID, ProductID, FirstMonthPrice
FROM         MMS.dbo.PKProductOverrideStagingLog

