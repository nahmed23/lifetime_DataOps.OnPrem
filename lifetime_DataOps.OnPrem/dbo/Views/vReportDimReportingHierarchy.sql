
     
CREATE VIEW [dbo].[vReportDimReportingHierarchy] AS
             SELECT DimReportingHierarchyKey,
                    RegionType,
                    DivisionName,
                    SubdivisionName,
                    DepartmentName,
                    ProductGroupName,
                    ProductGroupSortOrder,
                    EffectiveDimDateKey,
                    ExpirationDimDateKey,
                    InsertedDateTime,
                    InsertUser,
                    BatchID
               FROM dbo.ReportDimReportingHierarchy
			      WITH (NOLOCK)

