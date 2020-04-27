CREATE TABLE [dbo].[ProductGroup] (
    [ProductGroupID]                       INT         IDENTITY (1, 1) NOT NULL,
    [ProductID]                            INT         NOT NULL,
    [ValProductGroupID]                    SMALLINT    NULL,
    [InsertedDateTime]                     DATETIME    CONSTRAINT [DF_ProductGroup_InsertedDateTime] DEFAULT (getdate()) NULL,
    [GLRevenueAccount]                     VARCHAR (5) NULL,
    [GLRevenueSubAccount]                  VARCHAR (7) NULL,
    [ValRevenueAllocationProductGroupID]   SMALLINT    NULL,
    [Old_vs_NewBusiness_TrackingFlag]      INT         DEFAULT ((0)) NOT NULL,
    [AvgDeliveredSessionPriceTrackingFlag] BIT         NOT NULL,
    CONSTRAINT [PK_ProductGroup] PRIMARY KEY NONCLUSTERED ([ProductGroupID] ASC),
    CONSTRAINT [FK_ProductGroup_ValProductGroup] FOREIGN KEY ([ValProductGroupID]) REFERENCES [dbo].[ValProductGroup] ([ValProductGroupID]),
    CONSTRAINT [FK_ProductGroup_ValRevenueAllocationProductGroup] FOREIGN KEY ([ValRevenueAllocationProductGroupID]) REFERENCES [dbo].[ValRevenueAllocationProductGroup] ([ValRevenueAllocationProductGroupID])
);


GO
CREATE NONCLUSTERED INDEX [IX_ValProductGroupID]
    ON [dbo].[ProductGroup]([ValProductGroupID] ASC) WITH (FILLFACTOR = 80);

