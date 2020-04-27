CREATE TABLE [dbo].[LongRunningSQL8] (
    [RowNumber]  INT            IDENTITY (1, 1) NOT NULL,
    [EventClass] INT            NULL,
    [TextData]   NTEXT          NULL,
    [LoginName]  NVARCHAR (128) NULL,
    [SPID]       INT            NULL,
    [Duration]   BIGINT         NULL,
    [StartTime]  DATETIME       NULL,
    [EndTime]    DATETIME       NULL,
    PRIMARY KEY CLUSTERED ([RowNumber] ASC)
);


GO
EXECUTE sp_addextendedproperty @name = N'Build', @value = 760, @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'LongRunningSQL8';


GO
EXECUTE sp_addextendedproperty @name = N'MajorVer', @value = 8, @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'LongRunningSQL8';


GO
EXECUTE sp_addextendedproperty @name = N'MinorVer', @value = 0, @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'LongRunningSQL8';

