


-- =============================================
-- Object:			mmsCorpReimbursement_HistoryExport
-- Author:			
-- Create date: 	
-- Description:		returns all member reimbursement history for the slected date range
-- Modified date:	1/21/2009 GRB: modified code to allow passage of ReimbursementProgramID instead
--					of ReimbursementProgramName, precipitated by inablitity to process value L'Oreal
--					because of it's embedded apostrophe;
-- 
-- EXEC mmsCorpReimbursement_HistoryExport '10', 'Apr 1, 2011', 'Apr 3, 2011'
-- =============================================

CREATE PROC [dbo].[mmsCorpReimbursement_HistoryExport] (
	@ProgramID VARCHAR(50),
	@UsageStartDate SMALLDATETIME,
	@UsageEndDate SMALLDATETIME
	)
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

SELECT RP.ReimbursementProgramName, VR.Description AS Region, C.ClubName,
M.JoinDate, MR.EnrollmentDate, MR.MemberID,
Case M.ValMemberTypeID When 1 Then 1 Else 0 End AS UniqueMembershipFlag,
M.FirstName, M.MiddleName, M.LastName, MRH.MembershipID,
MRH.ReimbursementProgramID, MRH.UsageFirstOfMonth,
MRH.ClubID, MRH.InsertedDateTime,
MRH.ReimbursementErrorCodeID, RE.ErrorDescription,
MRH.UpdatedDateTime, MRH.ReimbursementQualifiedFlag,
MRH.QualifiedClubUtilization, CY.CompanyName,
Status =	Case
				When MR.TerminationDate Is Null Then 'Active'
				Else 'Terminated'
			End,
MR.TerminationDate,
/******  Foreign Currency Stuff  *********/
	   VCC.CurrencyCode as LocalCurrencyCode,
       #PlanRate.PlanRate,
       @ReportingCurrencyCode as ReportingCurrencyCode,
	   MRH.MonthlyDues * #PlanRate.PlanRate as MonthlyDues,	  
	   MRH.MonthlyDues as LocalCurrency_MonthlyDues,	  
	   MRH.MonthlyDues * #ToUSDPlanRate.PlanRate as USD_MonthlyDues,
	   MRH.EstimatedReimbursementAmount * #PlanRate.PlanRate as EstimatedReimbursementAmount,	  
	   MRH.EstimatedReimbursementAmount as LocalCurrency_EstimatedReimbursementAmount,	  
	   MRH.EstimatedReimbursementAmount * #ToUSDPlanRate.PlanRate as USD_EstimatedReimbursementAmount,
	   MRH.ActualReimbursementAmount * #PlanRate.PlanRate as ActualReimbursementAmount,	  
	   MRH.ActualReimbursementAmount as LocalCurrency_ActualReimbursementAmount,	  
	   MRH.ActualReimbursementAmount * #ToUSDPlanRate.PlanRate as USD_ActualReimbursementAmount	  
/***************************************/

FROM dbo.vReimbursementProgram RP
LEFT JOIN dbo.vMemberReimbursement MR 
	ON RP.ReimbursementProgramID = MR.ReimbursementProgramID
LEFT JOIN dbo.vMember M
	ON MR.MemberID = M.MemberID
LEFT JOIN dbo.vMemberReimbursementHistory MRH
	ON RP.ReimbursementProgramID = MRH.ReimbursementProgramID
/********** Foreign Currency Stuff **********/
  JOIN vClub C2
	   ON MRH.ClubID = C2.ClubID
  JOIN vValCurrencyCode VCC
       ON C2.ValCurrencyCodeID = VCC.ValCurrencyCodeID
  JOIN #PlanRate
       ON VCC.CurrencyCode = #PlanRate.FromCurrencyCode
      AND YEAR(MRH.UsageFirstOfMonth) = #PlanRate.PlanYear
  JOIN #ToUSDPlanRate
       ON VCC.CurrencyCode = #ToUSDPlanRate.FromCurrencyCode
      AND YEAR(MRH.UsageFirstOfMonth) = #ToUSDPlanRate.PlanYear
/*******************************************/
	And MR.MemberID = MRH.MemberID
LEFT JOIN dbo.vMembership MS
	ON M.MembershipID = MS.MembershipID
LEFT JOIN dbo.vCompany CY
	ON MS.CompanyID = CY.CompanyID
LEFT JOIN dbo.vClub C
	ON MS.ClubID = C.ClubID
LEFT JOIN dbo.vValRegion VR
	ON C.ValRegionID = VR.ValRegionID
LEFT JOIN dbo.vReimbursementErrorCode RE
	ON MRH.ReimbursementErrorCodeID = RE.ReimbursementErrorCodeID
WHERE RP.ReimbursementProgramID = @ProgramID and
(MRH.UsageFirstOfMonth Between @UsageStartDate and @UsageEndDate) and
(MR.TerminationDate is Null or MR.TerminationDate > @UsageStartDate)
ORDER BY MR.ReimbursementProgramID, Mr.MemberID, MRH.UsageFirstOfMonth

DROP TABLE #PlanRate
DROP TABLE #ToUSDPlanRate

-- Report Logging
UPDATE HyperionReportLog
SET EndDateTime = getdate()
WHERE ReportLogID = @Identity

END

