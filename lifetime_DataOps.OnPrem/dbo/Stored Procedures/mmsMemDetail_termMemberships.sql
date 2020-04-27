



-- Procedure to get membership details for terminated memberships per club
-- EXEC mmsMemDetail_termMemberships 'May 1, 2011', 'May 18, 2011', 'New Hope, MN'
-- Parameters: Club, Startdate, EndDate

CREATE   PROC [dbo].[mmsMemDetail_termMemberships] (
   @StartDate SMALLDATETIME,
   @EndDate SMALLDATETIME,
   @ClubList VARCHAR(1000)
)

AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON
CREATE TABLE #tmpList (StringField VARCHAR(50))
CREATE TABLE #Clubs (ClubName VARCHAR(50))

-- Report Logging
DECLARE @Identity AS INT
INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
SET @Identity = @@IDENTITY

IF @ClubList <> 'All'

BEGIN
   --   INSERT INTO #Clubs EXEC procParseStringList @ClubList
   EXEC procParseStringList @ClubList
   INSERT INTO #Clubs (ClubName) SELECT StringField FROM #tmpList
   TRUNCATE TABLE #tmpList
END
ELSE
BEGIN
   INSERT INTO #Clubs VALUES('All')
END

/********  Foreign Currency Stuff ********/
DECLARE @ReportingCurrencyCode VARCHAR(15)
SET @ReportingCurrencyCode = 
(SELECT CASE WHEN COUNT(DISTINCT C.ValCurrencyCodeID) >=2 THEN 'USD' ELSE MAX(VCC.CurrencyCode) END AS ReportingCurrency
  FROM vClub C
  JOIN #Clubs ON C.ClubName = #Clubs.ClubName OR #Clubs.ClubName = 'All'
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

SELECT C.ClubName, VR.Description AS RegionDescription, M.MemberID,
       M.FirstName, M.LastName, 
	   M.JoinDate as JoinDate_Sort,
	   Replace(SubString(Convert(Varchar, M.JoinDate),1,3)+' '+LTRIM(SubString(Convert(Varchar, M.JoinDate),5,DataLength(Convert(Varchar, M.JoinDate))-12)),' '+Convert(Varchar,Year(M.JoinDate)),', '+Convert(Varchar,Year(M.JoinDate))) as JoinDate,
       PP.ValPhoneTypeID, MSP.AreaCode, MSP.Number,
       VMSS.Description AS MembershipStatusDescription, 
	   MS.ExpirationDate as ExpirationDate_Sort, 
	   Replace(SubString(Convert(Varchar, MS.ExpirationDate),1,3)+' '+LTRIM(SubString(Convert(Varchar, MS.ExpirationDate),5,DataLength(Convert(Varchar, MS.ExpirationDate))-12)),' '+Convert(Varchar,Year(MS.ExpirationDate)),', '+Convert(Varchar,Year(MS.ExpirationDate))) as ExpirationDate,
       MS.MembershipID, MS.CancellationRequestDate, 
       P.Description AS MembershipTypeDescription,
       E.FirstName AS AdvisorFirstName, E.LastName AS AdvisorLastName, VTR.Description AS TerminationReason,
/******  Foreign Currency Stuff  *********/
	   VCC.CurrencyCode as LocalCurrencyCode,
       #PlanRate.PlanRate,
       @ReportingCurrencyCode as ReportingCurrencyCode,
	   MSB.CurrentBalance * #PlanRate.PlanRate as CurrentBalance,	  
	   MSB.CurrentBalance as LocalCurrency_CurrentBalance,	  
	   MSB.CurrentBalance * #ToUSDPlanRate.PlanRate as USD_CurrentBalance	   
/***************************************/

  FROM dbo.vMember M
  JOIN dbo.vMembership MS
       ON M.MembershipID = MS.MembershipID
  JOIN dbo.vValMemberType VMT
       ON M.ValMemberTypeID = VMT.ValMemberTypeID
  JOIN dbo.vValMembershipStatus VMSS
       ON MS.ValMembershipStatusID = VMSS.ValMembershipStatusID
  LEFT JOIN dbo.vEmployee E
       ON MS.AdvisorEmployeeID = E.EmployeeID
  LEFT JOIN dbo.vValTerminationReason VTR
       ON MS.ValTerminationReasonID = VTR.ValTerminationReasonID
  JOIN dbo.vClub C
       ON MS.ClubID = C.ClubID
  JOIN #Clubs CS
       ON C.ClubName = CS.ClubName OR CS.ClubName = 'All'
/********** Foreign Currency Stuff **********/
  JOIN vValCurrencyCode VCC
       ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID
  JOIN #PlanRate
       ON VCC.CurrencyCode = #PlanRate.FromCurrencyCode
      AND YEAR(MS.ExpirationDate) = #PlanRate.PlanYear
  JOIN #ToUSDPlanRate
       ON VCC.CurrencyCode = #ToUSDPlanRate.FromCurrencyCode
      AND YEAR(MS.ExpirationDate) = #ToUSDPlanRate.PlanYear
/*******************************************/
  JOIN dbo.vValRegion VR
       ON C.ValRegionID = VR.ValRegionID
  LEFT OUTER JOIN dbo.vMembershipBalance MSB 
       ON (MSB.MembershipID = MS.MembershipID) 
  LEFT OUTER JOIN dbo.vMembershipType MST 
       ON (MS.MembershipTypeID = MST.MembershipTypeID) 
  LEFT OUTER JOIN dbo.vProduct P 
       ON (MST.ProductID = P.ProductID) 
  LEFT OUTER JOIN dbo.vPrimaryPhone PP 
       ON (MS.MembershipID = PP.MembershipID) 
  LEFT OUTER JOIN dbo.vMembershipPhone MSP 
       ON (PP.MembershipID = MSP.MembershipID AND 
       PP.ValPhoneTypeID = MSP.ValPhoneTypeID)
 WHERE VMSS.Description = 'Terminated' AND
       --(C.ClubName IN (SELECT ClubName from #Clubs) OR
       --@ClubList = 'All') AND
       MS.ExpirationDate BETWEEN @StartDate AND @EndDate AND
       VMT.Description = 'Primary'
       
DROP TABLE #Clubs
DROP TABLE #tmpList
DROP TABLE #PlanRate
DROP TABLE #ToUSDPlanRate

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END

