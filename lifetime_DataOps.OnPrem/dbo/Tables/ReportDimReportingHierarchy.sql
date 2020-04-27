CREATE TABLE [dbo].[ReportDimReportingHierarchy] (
    [DimReportingHierarchyKey] INT           NOT NULL,
    [RegionType]               VARCHAR (50)  NOT NULL,
    [DivisionName]             VARCHAR (255) NOT NULL,
    [SubdivisionName]          VARCHAR (255) NOT NULL,
    [DepartmentName]           VARCHAR (255) NOT NULL,
    [ProductGroupName]         VARCHAR (255) NOT NULL,
    [ProductGroupSortOrder]    INT           NOT NULL,
    [EffectiveDimDateKey]      INT           NOT NULL,
    [ExpirationDimDateKey]     INT           NOT NULL,
    [InsertedDateTime]         DATETIME      DEFAULT (getdate()) NOT NULL,
    [InsertUser]               VARCHAR (50)  DEFAULT (suser_sname()) NOT NULL,
    [BatchID]                  INT           NOT NULL,
    CONSTRAINT [PK_DimReportingHierarchyKey] PRIMARY KEY CLUSTERED ([DimReportingHierarchyKey] ASC) WITH (FILLFACTOR = 70)
);

