CREATE TABLE [dbo].[ValProductGroup] (
    [ValProductGroupID]          SMALLINT     NOT NULL,
    [Description]                VARCHAR (50) NULL,
    [SortOrder]                  SMALLINT     NULL,
    [InsertedDateTime]           DATETIME     CONSTRAINT [DF_ValProductGroup_InsertedDateTime] DEFAULT (getdate()) NULL,
    [MemberActivitiesSortOrder]  TINYINT      NULL,
    [TennisSortOrder]            TINYINT      NULL,
    [AquaticsSortOrder]          TINYINT      NULL,
    [RevenueReportingDepartment] VARCHAR (50) NULL,
    [RevenueReportingRegionType] VARCHAR (50) NULL,
    CONSTRAINT [PK_ValProductGroup] PRIMARY KEY NONCLUSTERED ([ValProductGroupID] ASC)
);

