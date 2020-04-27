




--
-- Returns Membership status info - for memberships enrolled in one of the Corporate Wellness 
-- Healthcare Programs
-- EXEC mmsMemberstatussummary_Scheduled_Corp_Healthcare

CREATE      PROC [dbo].[mmsMemberstatussummary_Scheduled_Corp_Healthcare]


AS
BEGIN 
SET XACT_ABORT ON
SET NOCOUNT ON

DECLARE @ReportDate DATETIME
SET @ReportDate =  CONVERT(DATETIME, CONVERT(VARCHAR, GETDATE(), 102), 102)

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

SELECT M.MemberID, M.MembershipID, MR.EnrollmentDate, MR.TerminationDate AS EnrollmentTerminationDate, 
RP.ReimbursementProgramName, MT.ShortTermMembershipFlag, P.ProductID, P.Description AS ProductDescription, 
C.ClubName, R.Description AS RegionDescription, CP.ClubID, MS.ExpirationDate, GETDATE()  AS ReportDateTime, 
VMS.Description AS MembershipStatusDescription,
/******  Foreign Currency Stuff  *********/
	   VCC.CurrencyCode as LocalCurrencyCode,
       #PlanRate.PlanRate,
       @ReportingCurrencyCode as ReportingCurrencyCode,	   
	   CP.Price * #PlanRate.PlanRate as Price,	  
	   CP.Price as LocalCurrency_Price,	  
	   CP.Price * #ToUSDPlanRate.PlanRate as USD_Price	   
/***************************************/

FROM vMemberReimbursement MR
  JOIN vMember M
    ON MR.MemberID=M.MemberID
  JOIN vReimbursementProgram RP
    ON MR.ReimbursementProgramID=RP.ReimbursementProgramID
  JOIN vMembership MS
    ON M.MembershipID=MS.MembershipID 
  JOIN vMembershipType MT
    ON MS.MembershipTypeID=MT.MembershipTypeID
  JOIN vClubProduct CP
    ON MS.ClubID=CP.ClubID 
          AND MT.ProductID=CP.ProductID 
  JOIN vProduct P
    ON CP.ProductID=P.ProductID 
  JOIN vCLUB C
    ON CP.ClubID=C.ClubID
/********** Foreign Currency Stuff **********/
  JOIN vValCurrencyCode VCC
       ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID
  JOIN #PlanRate
       ON VCC.CurrencyCode = #PlanRate.FromCurrencyCode
      AND YEAR(GETDATE()) = #PlanRate.PlanYear
  JOIN #ToUSDPlanRate
       ON VCC.CurrencyCode = #ToUSDPlanRate.FromCurrencyCode
      AND YEAR(GETDATE()) = #ToUSDPlanRate.PlanYear
/*******************************************/
  JOIN vValRegion R
    ON C.ValRegionID=R.ValRegionID
  JOIN vValMembershipStatus VMS 
    ON VMS.ValMembershipStatusID=MS.ValMembershipStatusID

WHERE (MR.TerminationDate>= @ReportDate OR MR.TerminationDate IS NULL) 
               AND MR.EnrollmentDate<= @ReportDate 
               AND VMS.Description IN ('Active', 'Non-Paid', 'Pending Termination')

DROP TABLE #PlanRate
DROP TABLE #ToUSDPlanRate

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity


END

