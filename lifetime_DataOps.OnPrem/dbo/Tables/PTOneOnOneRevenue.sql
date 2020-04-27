CREATE TABLE [dbo].[PTOneOnOneRevenue] (
    [PTOneOnOneRevenueID] INT             IDENTITY (1, 1) NOT NULL,
    [ClubID]              INT             NULL,
    [EmployeeID]          INT             NULL,
    [ProductID]           INT             NULL,
    [PayPeriod]           VARCHAR (7)     NULL,
    [SalesTotal]          NUMERIC (12, 2) NULL,
    [ServiceRevenueTotal] NUMERIC (12, 2) NULL,
    [InsertedDateTime]    DATETIME        CONSTRAINT [DF_PTOneOnOneRevenue_InsertedDateTime] DEFAULT (getdate()) NULL,
    [InsertUser]          VARCHAR (50)    CONSTRAINT [DF_PTOneOnOneRevenue_InsertUser] DEFAULT (suser_sname()) NULL,
    [BatchID]             INT             NULL,
    CONSTRAINT [PK_PTOneOnOneRevenue] PRIMARY KEY CLUSTERED ([PTOneOnOneRevenueID] ASC)
);


GO
CREATE NONCLUSTERED INDEX [IX_ClubID]
    ON [dbo].[PTOneOnOneRevenue]([ClubID] ASC);


GO
CREATE NONCLUSTERED INDEX [IX_EmployeeID]
    ON [dbo].[PTOneOnOneRevenue]([EmployeeID] ASC);


GO
CREATE NONCLUSTERED INDEX [IX_ProductID]
    ON [dbo].[PTOneOnOneRevenue]([ProductID] ASC);


GO
CREATE NONCLUSTERED INDEX [IX_PayPeriod]
    ON [dbo].[PTOneOnOneRevenue]([PayPeriod] ASC);

