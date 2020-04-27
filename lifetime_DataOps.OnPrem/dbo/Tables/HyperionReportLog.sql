CREATE TABLE [dbo].[HyperionReportLog] (
    [ReportLogID]   INT           IDENTITY (1, 1) NOT NULL,
    [SPName]        VARCHAR (150) NULL,
    [StartDateTime] DATETIME      NULL,
    [EndDateTime]   DATETIME      NULL,
    CONSTRAINT [PK_HyperionReportLog] PRIMARY KEY NONCLUSTERED ([ReportLogID] ASC)
);

