CREATE TABLE [dbo].[ProductGroupByClub] (
    [ProductGroupByClubID]               INT          IDENTITY (1, 1) NOT NULL,
    [ProductID]                          INT          NOT NULL,
    [MMSClubID]                          INT          NOT NULL,
    [ValProductGroupID]                  SMALLINT     NULL,
    [GLRevenueAccount]                   VARCHAR (5)  NULL,
    [GLRevenueSubAccount]                VARCHAR (11) NULL,
    [ValRevenueAllocationProductGroupID] SMALLINT     NULL,
    [InsertedDateTime]                   DATETIME     CONSTRAINT [DF_ProductGroupByClub_InsertedDateTime] DEFAULT (getdate()) NULL,
    CONSTRAINT [PK_ProductGroupByClub] PRIMARY KEY NONCLUSTERED ([ProductGroupByClubID] ASC),
    CONSTRAINT [FK_ProductGroupByClub_ValProductGroup] FOREIGN KEY ([ValProductGroupID]) REFERENCES [dbo].[ValProductGroup] ([ValProductGroupID]),
    CONSTRAINT [FK_ProductGroupByClub_ValRevenueAllocationProductGroup] FOREIGN KEY ([ValRevenueAllocationProductGroupID]) REFERENCES [dbo].[ValRevenueAllocationProductGroup] ([ValRevenueAllocationProductGroupID])
);

