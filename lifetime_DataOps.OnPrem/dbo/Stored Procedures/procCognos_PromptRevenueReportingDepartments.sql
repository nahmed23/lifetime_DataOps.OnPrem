
CREATE PROC [dbo].[procCognos_PromptRevenueReportingDepartments] 

AS
BEGIN 
SET XACT_ABORT ON
SET NOCOUNT ON

SELECT ValProductGroup.RevenueReportingDepartment, Product.GLAccountNumber
FROM vProductGroup ProductGroup
JOIN vValProductGroup ValProductGroup on ProductGroup.ValProductGroupID = ValProductGroup.ValProductGroupID
JOIN vProduct Product on ProductGroup.ProductID = Product.ProductID
GROUP BY ValProductGroup.RevenueReportingDepartment, Product.GLAccountNumber


END
