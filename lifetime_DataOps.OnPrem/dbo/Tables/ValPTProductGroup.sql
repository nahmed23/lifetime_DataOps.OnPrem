CREATE TABLE [dbo].[ValPTProductGroup] (
    [ValPTProductGroupID] SMALLINT     NOT NULL,
    [Description]         VARCHAR (50) NULL,
    [SortOrder]           SMALLINT     NULL,
    [ServiceFlag]         BIT          CONSTRAINT [DF_ValPTProductGroup_ServiceFlag] DEFAULT ((0)) NOT NULL,
    [InsertedDateTime]    DATETIME     CONSTRAINT [DF_ValPTProductGroup_InsertedDateTime] DEFAULT (getdate()) NULL,
    CONSTRAINT [PK_ValPTProductGroup] PRIMARY KEY NONCLUSTERED ([ValPTProductGroupID] ASC)
);

