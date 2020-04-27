CREATE TABLE [dbo].[ValBinRangeSource] (
    [ValBinRangeSourceID] TINYINT      IDENTITY (1, 1) NOT FOR REPLICATION NOT NULL,
    [Description]         VARCHAR (50) NOT NULL,
    [SortOrder]           TINYINT      NOT NULL,
    [InsertedDateTime]    DATETIME     NULL,
    [UpdatedDateTime]     DATETIME     NULL,
    CONSTRAINT [PK_ValBinRangeSource] PRIMARY KEY CLUSTERED ([ValBinRangeSourceID] ASC)
);

