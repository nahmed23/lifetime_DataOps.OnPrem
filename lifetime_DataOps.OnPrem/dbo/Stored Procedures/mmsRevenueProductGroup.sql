
CREATE PROC [dbo].[mmsRevenueProductGroup] 
AS
BEGIN 
SET XACT_ABORT ON
SET NOCOUNT ON

SELECT DimProduct.MMSProductID ProductID,
       DimProduct.ProductDescription,
       DimProduct.DimReportingHierarchyKey,
       DimReportingHierarchy.ProductGroupName RevenueProductGroup,
       DimReportingHierarchy.DepartmentName RevenueReportingDepartment,
       DimReportingHierarchy.SubdivisionName Subdivision,
       DimReportingHierarchy.DivisionName Division
  FROM vReportDimProduct DimProduct
  JOIN vReportDimReportingHierarchy DimReportingHierarchy
    ON DimProduct.DimReportingHierarchyKey = DimReportingHierarchy.DimReportingHierarchyKey
 WHERE DimProduct.MMSProductID > 0
   AND DimReportingHierarchy.ProductGroupName <> ''

END
