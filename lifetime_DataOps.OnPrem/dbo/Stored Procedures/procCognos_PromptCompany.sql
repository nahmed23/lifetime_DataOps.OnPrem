



CREATE PROC [dbo].[procCognos_PromptCompany] 

AS
BEGIN 
SET XACT_ABORT ON
SET NOCOUNT ON

SELECT CompanyName, 
       Upper(SUBSTRING(LTRIM(CompanyName),1,1)) AS CompanyName_FirstCharacter,
       CompanyID,
       CorporateCode,
       ISNULL(InvoiceFlag,0) as InvoiceFlag,
	   CompanyName +' - '+ CorporateCode as CompanyNameDashCorporateCode,
	   AccountRepName,
       AccountOwner,
       ISNULL(ActiveAccountFlag,1) as ActiveAccountFlag
  FROM vCompany
 WHERE CompanyName IS NOT NULL

END


