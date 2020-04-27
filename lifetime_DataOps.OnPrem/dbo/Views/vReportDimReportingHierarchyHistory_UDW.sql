


     
CREATE VIEW [dbo].[vReportDimReportingHierarchyHistory_UDW] AS
             SELECT dim_reporting_hierarchy_key,
			        effective_dim_date_key,
					expiration_dim_date_key,
					reporting_division,
					reporting_sub_division,
					reporting_department,
					reporting_product_group,
					reporting_region_type
               FROM dbo.ReportDimReportingHierarchyHistory_UDW
			      WITH (NOLOCK)




