CREATE TABLE [dbo].[MonthlyAverageExchangeRate] (
    [MonthlyAverageExchangeRateID] INT             NOT NULL,
    [FirstOfMonthDate]             DATETIME        NOT NULL,
    [EndOfMonthDate]               DATETIME        NOT NULL,
    [FromCurrencyCode]             VARCHAR (15)    NOT NULL,
    [ToCurrencyCode]               VARCHAR (15)    NOT NULL,
    [MonthlyAverageExchangeRate]   DECIMAL (14, 4) NOT NULL,
    [InsertedDateTime]             DATETIME        DEFAULT (getdate()) NOT NULL,
    [InsertUser]                   VARCHAR (50)    DEFAULT (suser_sname()) NOT NULL,
    [BatchID]                      INT             NOT NULL,
    CONSTRAINT [PK_MonthlyAverageExchangeRateID] PRIMARY KEY CLUSTERED ([MonthlyAverageExchangeRateID] ASC) WITH (FILLFACTOR = 70)
);


GO
CREATE NONCLUSTERED INDEX [IX_FirstOfMonthDate]
    ON [dbo].[MonthlyAverageExchangeRate]([FirstOfMonthDate] ASC) WITH (FILLFACTOR = 70);


GO
CREATE NONCLUSTERED INDEX [IX_ToCurrencyCode]
    ON [dbo].[MonthlyAverageExchangeRate]([ToCurrencyCode] ASC) WITH (FILLFACTOR = 70);

