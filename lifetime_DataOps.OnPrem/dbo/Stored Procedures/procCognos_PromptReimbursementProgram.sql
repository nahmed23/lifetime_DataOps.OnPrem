


CREATE PROC [dbo].[procCognos_PromptReimbursementProgram]
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

SELECT RP.ReimbursementProgramID, 
       RP.ReimbursementProgramName, 
       RP.ActiveFlag, 
       RP.InsertedDateTime,
	   RP.UpdatedDateTime,
       ISNULL(CO.CompanyName,'None Designated') PartnerProgramCompanyName, -- ACME-08 11-7-2012
	   ISNULL(CO.CompanyID,-1) PartnerProgramCompanyID,
	   CO.CorporateCode
FROM vReimbursementProgram RP
 LEFT JOIN vCompany CO-- ACME-08 11-7-2012
    ON RP.CompanyID = CO.CompanyID-- ACME-08 11-7-2012


END



