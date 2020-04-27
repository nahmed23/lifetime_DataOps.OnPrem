


     
CREATE VIEW [dbo].[vReportDimClubHistory_UDW] AS
             SELECT dim_club_key,
                    club_id,
                    effective_date_time,
                    expiration_date_time,
                    city,
                    club_close_dim_date_key,
                    club_code,
                    club_name,
                    club_open_dim_date_key,
                    club_status,
                    club_type,
                    country,
                    local_currency_code,
                    member_activities_region_dim_description_key,
                    pt_rcl_area_dim_description_key,
                    region_dim_description_key,
                    sales_area_dim_description_key,
                    state_or_province,
                    workday_region
               FROM dbo.ReportDimClubHistory_UDW
			      WITH (NOLOCK)



