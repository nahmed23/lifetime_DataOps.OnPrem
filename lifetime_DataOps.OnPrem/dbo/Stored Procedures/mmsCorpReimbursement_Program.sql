
-- EXEC mmsCorpReimbursement_Program
-- Returns list of all corporate reimbursement programs
--

CREATE PROC [dbo].[mmsCorpReimbursement_Program]
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

/********  Foreign Currency Stuff ********/
DECLARE @ReportingCurrencyCode VARCHAR(15)
SET @ReportingCurrencyCode = 
(SELECT CASE WHEN COUNT(DISTINCT C.ValCurrencyCodeID) >=2 THEN 'USD' ELSE MAX(VCC.CurrencyCode) END AS ReportingCurrency
  FROM vClub C 
  JOIN vValCurrencyCode VCC ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID)

CREATE TABLE #PlanRate (PlanRate DECIMAL(14,4), FromCurrencyCode VARCHAR(15), PlanYear INT)
INSERT INTO #PlanRate
SELECT PlanExchangeRate, FromCurrencyCode, PlanYear
FROM PlanExchangeRate
WHERE ToCurrencyCode = @ReportingCurrencyCode

CREATE TABLE #ToUSDPlanRate (PlanRate DECIMAL(14,4), FromCurrencyCode VARCHAR(15), PlanYear INT)
INSERT INTO #ToUSDPlanRate
SELECT PlanExchangeRate, FromCurrencyCode, PlanYear
FROM PlanExchangeRate
WHERE ToCurrencyCode = 'USD'
/***************************************/

SELECT RP.ReimbursementProgramID, RP.ReimbursementProgramName, RP.ActiveFlag, RP.InsertedDateTime,
		RP.UpdatedDateTime,
/******  Foreign Currency Stuff  *********/
	   VCC.CurrencyCode as LocalCurrencyCode,
       #PlanRate.PlanRate,
       @ReportingCurrencyCode as ReportingCurrencyCode,
	   RP.DuesSubsidyAmount * #PlanRate.PlanRate as DuesSubsidyAmount,	  
	   RP.DuesSubsidyAmount as LocalCurrency_DuesSubsidyAmount,	  
	   RP.DuesSubsidyAmount * #ToUSDPlanRate.PlanRate as USD_DuesSubsidyAmount,
/***************************************/	    
       ISNULL(CO.CompanyName,'None Designated') PartnerProgramCompanyName -- ACME-08 11-7-2012
From dbo.vReimbursementProgram RP
/********** Foreign Currency Stuff **********/
	JOIN vMemberReimbursement MR
	 ON RP.ReimbursementProgramID = MR.ReimbursementProgramID
	JOIN vMember M
	 ON MR.MemberID = M.MemberID
	JOIN vMembership MS
	 ON M.MembershipID = MS.MembershipID
	JOIN vClub C
	 ON MS.ClubID = C.ClubID
  JOIN vValCurrencyCode VCC
       ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID
  JOIN #PlanRate
       ON VCC.CurrencyCode = #PlanRate.FromCurrencyCode
      AND YEAR(RP.InsertedDateTime) = #PlanRate.PlanYear
  JOIN #ToUSDPlanRate
       ON VCC.CurrencyCode = #ToUSDPlanRate.FromCurrencyCode
      AND YEAR(RP.InsertedDateTime) = #ToUSDPlanRate.PlanYear
/*******************************************/
  LEFT JOIN vCompany CO-- ACME-08 11-7-2012
    ON RP.CompanyID = CO.CompanyID-- ACME-08 11-7-2012

GROUP BY RP.ReimbursementProgramID, RP.ReimbursementProgramName, RP.ActiveFlag, RP.InsertedDateTime,
		RP.UpdatedDateTime, VCC.CurrencyCode, #PlanRate.PlanRate, #ToUSDPlanRate.PlanRate, RP.DuesSubsidyAmount,
		ISNULL(CO.CompanyName,'None Designated')-- ACME-08 11-7-2012

DROP TABLE #PlanRate
DROP TABLE #ToUSDPlanRate

-- Report Logging
UPDATE HyperionReportLog
SET EndDateTime = getdate()
WHERE ReportLogID = @Identity

END
