

Create PROC [dbo].[procCognos_PromptBDM] 

AS
BEGIN 
SET XACT_ABORT ON
SET NOCOUNT ON

SELECT Distinct 
  CO.AccountOwner
FROM
  vCompany CO
WHERE CO.AccountOwner IS NOT NULL
  AND CO.ActiveAccountFlag = 1
  AND CO.OpportunityRecordType ='Corporate Partnership Opportunity'

ORDER BY CO.AccountOwner

END
