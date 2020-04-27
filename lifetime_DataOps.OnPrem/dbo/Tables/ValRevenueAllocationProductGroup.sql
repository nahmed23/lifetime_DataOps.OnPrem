CREATE TABLE [dbo].[ValRevenueAllocationProductGroup] (
    [ValRevenueAllocationProductGroupID] SMALLINT     NOT NULL,
    [Description]                        VARCHAR (50) NULL,
    [SortOrder]                          SMALLINT     NULL,
    [InsertedDateTime]                   DATETIME     CONSTRAINT [DF_ValRevenueAllocationProductGroup_InsertedDateTime] DEFAULT (getdate()) NULL,
    CONSTRAINT [PK_ValRevenueAllocationProductGroup] PRIMARY KEY CLUSTERED ([ValRevenueAllocationProductGroupID] ASC)
);

