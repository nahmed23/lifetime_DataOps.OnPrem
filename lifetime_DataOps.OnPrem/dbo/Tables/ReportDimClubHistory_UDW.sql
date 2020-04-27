CREATE TABLE [dbo].[ReportDimClubHistory_UDW] (
    [dim_club_key]                                 NVARCHAR (255) NULL,
    [club_id]                                      FLOAT (53)     NULL,
    [effective_date_time]                          DATETIME       NULL,
    [expiration_date_time]                         DATETIME       NULL,
    [city]                                         NVARCHAR (255) NULL,
    [club_close_dim_date_key]                      FLOAT (53)     NULL,
    [club_code]                                    NVARCHAR (255) NULL,
    [club_name]                                    NVARCHAR (255) NULL,
    [club_open_dim_date_key]                       FLOAT (53)     NULL,
    [open_dim_date_key]                            FLOAT (53)     NULL,
    [club_status]                                  NVARCHAR (255) NULL,
    [club_type]                                    NVARCHAR (255) NULL,
    [country]                                      NVARCHAR (255) NULL,
    [local_currency_code]                          NVARCHAR (255) NULL,
    [member_activities_region_dim_description_key] FLOAT (53)     NULL,
    [pt_rcl_area_dim_description_key]              FLOAT (53)     NULL,
    [region_dim_description_key]                   NVARCHAR (255) NULL,
    [sales_area_dim_description_key]               FLOAT (53)     NULL,
    [state_or_province]                            NVARCHAR (255) NULL,
    [workday_region]                               NVARCHAR (255) NULL,
    [Report_MMS_inserted_date]                     DATETIME       NULL
);

