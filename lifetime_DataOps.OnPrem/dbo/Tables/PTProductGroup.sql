CREATE TABLE [dbo].[PTProductGroup] (
    [PTProductGroupID]    INT          IDENTITY (1, 1) NOT NULL,
    [ProductID]           INT          NOT NULL,
    [ValPTProductGroupID] SMALLINT     NOT NULL,
    [UpdatedDateTime]     DATETIME     NULL,
    [InsertedDateTime]    DATETIME     CONSTRAINT [DF_PTProductGroup_InsertedDateTime] DEFAULT (getdate()) NULL,
    [InsertUser]          VARCHAR (50) CONSTRAINT [DF_PTProductGroup_InsertUser] DEFAULT (suser_sname()) NULL,
    [UpdatedUser]         VARCHAR (50) NULL,
    CONSTRAINT [PK_PTProductGroup] PRIMARY KEY NONCLUSTERED ([PTProductGroupID] ASC)
);


GO
CREATE NONCLUSTERED INDEX [IX_ProductID]
    ON [dbo].[PTProductGroup]([ProductID] ASC);


GO
CREATE NONCLUSTERED INDEX [IX_ValPTProductGroupID]
    ON [dbo].[PTProductGroup]([ValPTProductGroupID] ASC);

