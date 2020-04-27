
CREATE VIEW [dbo].[vRevenueAllocationRates]
AS
SELECT RevenueAllocationRatesID,
	   PostingMonth,
	   ValRevenueAllocationProductGroupID,
	   Ratio,
	   AccumulatedRatio,
	   ActivityFinalPostingMonth
FROM   dbo.RevenueAllocationRates WITH (NOLOCK)
