




CREATE     PROC [dbo].[mmsMajorityusageexception_SummaryCalc] (
  @RegionDescription VARCHAR(50),
  @UsageDate SMALLDATETIME
  )
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- EXEC mmsMajorityusageexception_SummaryCalc 'East-OhioIN', 'May 1, 2011'
-- Returns memberships and their usage by club
--
-- Parameters: a usage date to limit how far back the counts go and a Region
--
-- 09/15/2010 MLL Added UsageClubID to result set

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
/***************************************/

CREATE TABLE #MU (MemberUsageID INT, MemberID INT, ClubID INT, UsageDateTime DateTime, CheckInDelinquentFlag Bit, PlanYear INT,
                  UsageClubName Varchar(50), UsageClubID INT, MembershipID INT, MembershipClubID INT,MembershipTypeID INT)

INSERT INTO #MU
SELECT MU.MemberUsageID, MU.MemberID, MU.ClubID, MU.UsageDateTime, MU.CheckinDelinquentFlag, YEAR(MU.UsageDateTime) PlanYear,
       C1.ClubName UsageClubName, C1.ClubID UsageClubID, MS.MembershipID, MS.ClubID MembershipClubID, MS.MembershipTypeID
FROM vMemberUsage MU
JOIN dbo.vMember M ON MU.MemberID = M.MemberID
JOIN dbo.vClub C1 ON MU.ClubID = C1.ClubID
JOIN dbo.vValRegion VRID ON C1.ValRegionID = VRID.ValRegionID
JOIN dbo.vMembership MS ON M.MembershipID = MS.MembershipID
JOIN dbo.vValMembershipStatus VMS ON MS.ValMembershipStatusID = VMS.ValMembershipStatusID
WHERE UsageDateTime >= @UsageDate
  AND VMS.Description IN ('Active', 'Late Activation', 'Non-Paid', 'Non-Paid, Late Activation', 'Pending Termination', 'Suspended')
  AND VRID.Description = @RegionDescription       


SELECT MU.MembershipID, 
       Count (MU.MemberUsageID) MemberUsageID, 
       MU.UsageClubname,
       C2.ClubName MembershipClubname, 
       P.Description [Membership Type Description], 
       P.ProductID [Membership Product ID],       
       MU.UsageClubID,
	   VCC.CurrencyCode as LocalCurrencyCode,
       PlanRate.PlanExchangeRate,
       @ReportingCurrencyCode as ReportingCurrencyCode,
	   CP.Price * PlanRate.PlanExchangeRate as [Dues Price],	  
	   CP.Price as [LocalCurrency_Dues Price],	  
	   CP.Price * USDPlanRate.PlanExchangeRate as [USD_Dues Price]   
FROM #MU MU
JOIN dbo.vClub C2 ON MU.MembershipClubID = C2.ClubID
JOIN vValCurrencyCode VCC
  ON C2.ValCurrencyCodeID = VCC.ValCurrencyCodeID
JOIN PlanExchangeRate PlanRate
  ON PlanRate.ToCurrencyCode = @ReportingCurrencyCode
 AND PlanRate.FromCurrencyCode = VCC.CurrencyCode
 AND PlanRate.PlanYear = MU.PlanYear
JOIN PlanExchangeRate USDPlanRate
  ON USDPlanRate.ToCurrencyCode = 'USD'
 AND USDPlanRate.FromCurrencyCode = VCC.CurrencyCode
 AND USDPlanRate.PlanYear = MU.PlanYear
JOIN dbo.vValRegion VRID2
  ON C2.ValRegionID = VRID2.ValRegionID
JOIN dbo.vClubProduct CP
  ON C2.ClubID = CP.ClubID
JOIN dbo.vMembershipType MT
  ON MU.MembershipTypeID = MT.MembershipTypeID
JOIN dbo.vProduct P
  ON CP.ProductID = P.ProductID
 AND MT.ProductID = P.ProductID
 WHERE VRID2.Description = @RegionDescription
 GROUP BY MU.MembershipID, 
       MU.UsageClubname,
       C2.ClubName, 
       P.Description, 
       P.ProductID,       
       MU.UsageClubID,
	   VCC.CurrencyCode,
       PlanRate.PlanExchangeRate,
       USDPlanRate.PlanExchangeRate,
       CP.Price         
	

DROP TABLE #MU

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END

