
CREATE VIEW dbo.vPKProductOverrideStaging
AS
SELECT     PKProductOverrideStagingID, PKMembershipStagingID, ProductID, FirstMonthPrice
FROM         MMS.dbo.PKProductOverrideStaging

