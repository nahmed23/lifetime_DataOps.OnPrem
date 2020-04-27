CREATE TABLE [dbo].[AuditQuery] (
    [Application] VARCHAR (50)  NULL,
    [Document]    VARCHAR (100) NULL,
    [Section]     VARCHAR (100) NULL,
    [Username]    VARCHAR (50)  NULL,
    [Parameters]  TEXT          NULL,
    [Rows]        INT           NULL,
    [StartDate]   DATETIME      NULL,
    [EndDate]     DATETIME      NULL
);

