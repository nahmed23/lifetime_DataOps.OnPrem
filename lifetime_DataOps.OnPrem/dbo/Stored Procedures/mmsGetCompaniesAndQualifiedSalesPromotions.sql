
CREATE    PROC [dbo].[mmsGetCompaniesAndQualifiedSalesPromotions]
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

SELECT distinct CompanyName CompanyNameOrPromotionName, 
                SUBSTRING(LTRIM(CompanyName),1,1) AS FirstCharacter,
                CompanyID CompanyIDOrSalesPromotionID,
                CorporateCode,
                'Company' RecordType,
                ISNULL(InvoiceFlag,0) UsageSubsidyFlag
  FROM dbo.vCompany
 WHERE CompanyName IS NOT NULL

UNION

SELECT DISTINCT PromotionName CompanyNameOrPromotionName,
                SUBSTRING(LTRIM(PromotionName),1,1) FirstCharacter,
                SalesPromotionID CompanyIDOrSalesPromotionID,
                'N/A' CorporateCode,
                'QualifiedSalesPromotion' RecordType,
                0 UsageSubsidyFlag
FROM vQualifiedSalesPromotion
ORDER BY RecordType,CompanyNameOrPromotionName

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END


