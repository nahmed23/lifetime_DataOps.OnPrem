CREATE TABLE [dbo].[PlanExchangeRate] (
    [PlanExchangeRateID] INT             NOT NULL,
    [PlanYear]           INT             NOT NULL,
    [FromCurrencyCode]   VARCHAR (15)    NOT NULL,
    [ToCurrencyCode]     VARCHAR (15)    NOT NULL,
    [PlanExchangeRate]   DECIMAL (14, 4) NOT NULL,
    [InsertedDateTime]   DATETIME        DEFAULT (getdate()) NOT NULL,
    [InsertUser]         VARCHAR (50)    DEFAULT (suser_sname()) NOT NULL,
    [BatchID]            INT             NOT NULL,
    CONSTRAINT [PK_PlanExchangeRateID] PRIMARY KEY CLUSTERED ([PlanExchangeRateID] ASC) WITH (FILLFACTOR = 70)
);


GO
CREATE NONCLUSTERED INDEX [IX_PlanYear]
    ON [dbo].[PlanExchangeRate]([PlanYear] ASC) WITH (FILLFACTOR = 70);


GO
CREATE NONCLUSTERED INDEX [IX_ToCurrencyCode]
    ON [dbo].[PlanExchangeRate]([ToCurrencyCode] ASC) WITH (FILLFACTOR = 70);

