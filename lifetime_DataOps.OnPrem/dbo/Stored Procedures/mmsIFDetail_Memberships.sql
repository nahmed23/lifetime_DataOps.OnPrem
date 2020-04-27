

-- EXEC mmsIFDetail_Memberships 'Apr 1, 2011', 'Apr 3, 2011'

----- Returns Membership and transaction data for memberships with IF transactions in the selected   
----- date range,yet only for dates since the 1st of the prior month

CREATE             PROC [dbo].[mmsIFDetail_Memberships](
		 @StartDate SMALLDATETIME,
 		 @EndDate SMALLDATETIME
)

AS 
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

DECLARE @FirstOfMonth DATETIME
DECLARE @FirstOfLastMonth DATETIME

SET @FirstOfMonth  =  CONVERT(DATETIME, SUBSTRING(CONVERT(VARCHAR, GETDATE(), 112),1,6) + '01', 112)
SET @FirstOfLastMonth = DATEADD(mm, -1, @FirstOfMonth)

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
WHERE PlanYear >= Year(@StartDate)
  AND PlanYear <= Year(@EndDate)
  AND ToCurrencyCode = @ReportingCurrencyCode

CREATE TABLE #ToUSDPlanRate (PlanRate DECIMAL(14,4), FromCurrencyCode VARCHAR(15), PlanYear INT)
INSERT INTO #ToUSDPlanRate
SELECT PlanExchangeRate, FromCurrencyCode, PlanYear
FROM PlanExchangeRate
WHERE PlanYear >= Year(@StartDate)
  AND PlanYear <= Year(@EndDate)
  AND ToCurrencyCode = 'USD'
/***************************************/

SELECT R.Description AS RegionDescription, C.ClubName AS MembershipClub, 
M.MemberID AS PrimaryMemberID, M.FirstName AS PrimaryFirstName, 
M.LastName AS PrimaryLastName, M.JoinDate AS PrimaryJoinDate, 
MS.CreatedDateTime AS MembershipCreateDateTime, P.Description AS MembershipTypeDescription, 
VF.Description AS MembershipSizeDescription,MS.MembershipID,
VS.Description AS MembershipEntrySourceDescription, CO.CorporateCode, CO.CompanyName,
E.FirstName AS AdvisorFirstName, E.LastName AS AdvisorLastName,C.ClubID AS MembershipClubID,
VET.Description AS EnrollmentTypeDescription,P.ProductID AS MembershipProductID,
CASE WHEN ( DATEDIFF(day, M.JoinDate, (ISNULL(MS.CreatedDateTime, CONVERT(DATETIME, 'JAN 01 2000', 100))))< -30)
     THEN 1
     ELSE 0
     END CreateDateToJoinDateIssueFlag,
C2.ClubName AS TransactionClubName, P2.ProductID, P2.Description AS ProductDescription,
MT.PostDateTime, VTT.Description AS TranTypeDescription,
/******  Foreign Currency Stuff  *********/
	   VCC.CurrencyCode as LocalCurrencyCode,
       #PlanRate.PlanRate,
       @ReportingCurrencyCode as ReportingCurrencyCode,
	   TI.ItemAmount * #PlanRate.PlanRate as ItemAmount,	   
	   TI.ItemAmount as LocalCurrency_ItemAmount,	   
	   TI.ItemAmount * #ToUSDPlanRate.PlanRate as USD_ItemAmount
/***************************************/
FROM vClub C 
JOIN vValRegion R
  ON  R.ValRegionID = C.ValRegionID
JOIN vMembership MS
  ON C.ClubID = MS.ClubID
JOIN vMember M
  ON M.MembershipID = MS.MembershipID
JOIN vValMembershipSource VS
  ON MS.ValMembershipSourceID = VS.ValMembershipSourceID
JOIN vMembershipType MST
  ON MS.MembershipTypeID = MST.MembershipTypeID
JOIN vProduct P
  ON P.ProductID = MST.ProductID
JOIN vValMembershipTypeFamilyStatus VF
  ON MST.ValMembershipTypeFamilyStatusID = VF.ValMembershipTypeFamilyStatusID
JOIN vEmployee E
  ON MS.AdvisorEmployeeID = E.EmployeeID
JOIN vValEnrollmentType VET
  ON VET.ValEnrollmentTypeID = MS.ValEnrollmentTypeID
JOIN vMMSTran MT
  ON MS.MembershipID = MT.MembershipID
JOIN vTranItem TI
  ON MT.MMSTranID = TI.MMSTranID
JOIN vProduct P2
  ON TI.ProductID = P2.ProductID
JOIN vValTranType VTT
  ON MT.ValTranTypeID = VTT.ValTranTypeID
JOIN vClub C2
  ON MT.ClubID = C2.ClubID
/********** Foreign Currency Stuff **********/
  JOIN vValCurrencyCode VCC
       ON C2.ValCurrencyCodeID = VCC.ValCurrencyCodeID
  JOIN #PlanRate
       ON VCC.CurrencyCode = #PlanRate.FromCurrencyCode
      AND YEAR(MT.PostDateTime) = #PlanRate.PlanYear
  JOIN #ToUSDPlanRate
       ON VCC.CurrencyCode = #ToUSDPlanRate.FromCurrencyCode
      AND YEAR(MT.PostDateTime) = #ToUSDPlanRate.PlanYear
/*******************************************/
LEFT  JOIN vCompany CO 
  ON MS.CompanyID = CO.CompanyID 

WHERE 
   P2.ProductID IN(88,286) AND ----- Initiation Fee or Initiation Fee Rejoin
   MT.PostDateTime >= @StartDate AND 
   MT.PostDateTime <= @EndDate AND
   MT.PostDateTime >= @FirstOfLastMonth AND
   MT.TranVoidedID IS NULL AND
   M.ValMemberTypeID = 1 AND
   VTT.ValTranTypeID IN(1,3,4)---- Charge, Sale or Adjustment

DROP TABLE #PlanRate
DROP TABLE #ToUSDPlanRate

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END

