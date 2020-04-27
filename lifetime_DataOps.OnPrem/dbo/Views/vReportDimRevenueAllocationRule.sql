

CREATE VIEW [dbo].[vReportDimRevenueAllocationRule]
AS
SELECT RevenueAllocationRuleName,
       RevenueAllocationRuleSet,
       DimLocationKey,
       RevenuePostingMonthStartingDimDateKey,
       RevenuePostingMonthEndingDimDateKey,
       RevenuePostingMonthFourDigitYearDashTwoDigitMonth,
       EarliestTransactionDimDateKey,
       LatestTransactionDimDateKey,
       RevenueFromLateTransactionFlag,
       Ratio,
       AccumulatedRatio,
       EffectiveDate,
       ExpirationDate,
       OneOffRuleFlag, 
       InsertedDateTime, 
       InsertUser,
       BatchID
FROM ReportDimRevenueAllocationRule
  WITH (NOLOCK)

