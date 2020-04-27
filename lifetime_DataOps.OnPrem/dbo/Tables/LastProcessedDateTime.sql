CREATE TABLE [dbo].[LastProcessedDateTime] (
    [LastProcessedDateTimeID] INT          NOT NULL,
    [Description]             VARCHAR (50) NOT NULL,
    [LastProcessedDateTime]   DATETIME     NOT NULL,
    CONSTRAINT [PK_LastProcessedDateTime] PRIMARY KEY NONCLUSTERED ([LastProcessedDateTimeID] ASC)
);

