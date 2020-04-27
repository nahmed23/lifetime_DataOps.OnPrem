CREATE TABLE [dbo].[RevenueAllocationRates] (
    [RevenueAllocationRatesID]           INT            IDENTITY (1, 1) NOT NULL,
    [PostingMonth]                       VARCHAR (6)    NULL,
    [ValRevenueAllocationProductGroupID] SMALLINT       NULL,
    [Ratio]                              DECIMAL (7, 5) NULL,
    [AccumulatedRatio]                   DECIMAL (7, 5) NULL,
    [ActivityFinalPostingMonth]          VARCHAR (6)    NULL,
    [InsertedDateTime]                   DATETIME       CONSTRAINT [DF_RevenueAllocationRates_InsertedDateTime] DEFAULT (getdate()) NULL,
    CONSTRAINT [PK_RevenueAllocationRates] PRIMARY KEY CLUSTERED ([RevenueAllocationRatesID] ASC),
    CONSTRAINT [FK_RevenueAllocationRates_ValRevenueAllocationProductGroup] FOREIGN KEY ([ValRevenueAllocationProductGroupID]) REFERENCES [dbo].[ValRevenueAllocationProductGroup] ([ValRevenueAllocationProductGroupID])
);

