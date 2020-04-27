CREATE TABLE [dbo].[ReportDimRevenueAllocationRule] (
    [RevenueAllocationRuleName]                         VARCHAR (50)     NOT NULL,
    [RevenueAllocationRuleSet]                          VARCHAR (57)     NOT NULL,
    [DimLocationKey]                                    INT              NOT NULL,
    [RevenuePostingMonthStartingDimDateKey]             INT              NOT NULL,
    [RevenuePostingMonthEndingDimDateKey]               INT              NOT NULL,
    [RevenuePostingMonthFourDigitYearDashTwoDigitMonth] CHAR (7)         NOT NULL,
    [EarliestTransactionDimDateKey]                     INT              NOT NULL,
    [LatestTransactionDimDateKey]                       INT              NOT NULL,
    [RevenueFromLateTransactionFlag]                    CHAR (1)         NOT NULL,
    [Ratio]                                             DECIMAL (11, 10) NOT NULL,
    [AccumulatedRatio]                                  DECIMAL (11, 10) NOT NULL,
    [EffectiveDate]                                     DATETIME         NOT NULL,
    [ExpirationDate]                                    DATETIME         NOT NULL,
    [OneOffRuleFlag]                                    CHAR (1)         NOT NULL,
    [InsertedDateTime]                                  DATETIME         DEFAULT (getdate()) NOT NULL,
    [InsertUser]                                        VARCHAR (50)     DEFAULT (suser_sname()) NOT NULL,
    [BatchID]                                           INT              NOT NULL,
    CONSTRAINT [CHECK_ReportDimRevenueAllocationRule_OneOffRuleFlag] CHECK ([OneOffRuleFlag]='N' OR [OneOffRuleFlag]='Y'),
    CONSTRAINT [CHECK_ReportDimRevenueAllocationRule_RevenueFromLateTransactionFlag] CHECK ([RevenueFromLateTransactionFlag]='N' OR [RevenueFromLateTransactionFlag]='Y')
);

