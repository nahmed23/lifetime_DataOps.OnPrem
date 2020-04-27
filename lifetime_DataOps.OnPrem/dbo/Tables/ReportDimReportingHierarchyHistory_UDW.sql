CREATE TABLE [dbo].[ReportDimReportingHierarchyHistory_UDW] (
    [dim_reporting_hierarchy_key] NVARCHAR (255) NULL,
    [effective_dim_date_key]      FLOAT (53)     NULL,
    [expiration_dim_date_key]     FLOAT (53)     NULL,
    [reporting_division]          NVARCHAR (255) NULL,
    [reporting_sub_division]      NVARCHAR (255) NULL,
    [reporting_department]        NVARCHAR (255) NULL,
    [reporting_product_group]     NVARCHAR (255) NULL,
    [reporting_region_type]       NVARCHAR (255) NULL,
    [Report_MMS_inserted_date]    DATETIME       NULL
);

