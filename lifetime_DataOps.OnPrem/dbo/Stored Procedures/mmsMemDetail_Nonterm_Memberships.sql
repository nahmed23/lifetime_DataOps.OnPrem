

-- Procedure to get membership details for Non terminated memberships per club
--
-- Parameters: Club, Startdate, EndDate, Membership status, membership type (product description)
-- EXEC mmsMemDetail_Nonterm_Memberships 'New Hope, MN', 'Active', 'All', 'Apr 1, 2011 12:00 AM', 'May 18, 2011 11:59 PM'

CREATE  PROC [dbo].[mmsMemDetail_Nonterm_Memberships] (
   @ClubList VARCHAR(1000),
   @MemStatusList VARCHAR(1000),
   @MemTypeList VARCHAR(8000),
   @JoinDateStart datetime,
   @JoinDateEnd datetime
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

CREATE TABLE #MemStatus (Description VARCHAR(50))
IF @MemStatusList <> 'All'
BEGIN
--   INSERT INTO #MemStatus EXEC procParseStringList @MemStatusList
   EXEC procParseStringList @MemStatusList
   INSERT INTO #MemStatus (Description) SELECT StringField FROM #tmpList
   TRUNCATE TABLE #tmpList
END
ELSE
BEGIN
   INSERT INTO #MemStatus VALUES('All') 
END
CREATE TABLE #MemType (Description VARCHAR(50))
IF @MemTypeList <> 'All'
BEGIN
--   INSERT INTO #MemType EXEC procParseStringList @MemTypeList
   EXEC procParseStringList @MemTypeList
   INSERT INTO #MemType (Description) SELECT StringField FROM #tmpList
   TRUNCATE TABLE #tmpList
END
ELSE
BEGIN
   INSERT INTO #MemType VALUES('All') 
END
SELECT C.ClubName, M.MemberID, M.FirstName,
       M.LastName, M.JoinDate as JoinDate_Sort, 
	   Replace(SubString(Convert(Varchar, M.JoinDate),1,3)+' '+LTRIM(SubString(Convert(Varchar, M.JoinDate),5,DataLength(Convert(Varchar, M.JoinDate))-12)),' '+Convert(Varchar,Year(M.JoinDate)),', '+Convert(Varchar,Year(M.JoinDate))) as JoinDate,
	   MSP.ValPhoneTypeID,
       MSP.AreaCode, MSP.Number, MS.MembershipID,
       VR.Description AS RegionDescription, 
       VMSS.Description AS MembershipStatusDescription,
       MS.ActivationDate as ActivationDate_Sort, 
	   Replace(SubString(Convert(Varchar, MS.ActivationDate),1,3)+' '+LTRIM(SubString(Convert(Varchar, MS.ActivationDate),5,DataLength(Convert(Varchar, MS.ActivationDate))-12)),' '+Convert(Varchar,Year(MS.ActivationDate)),', '+Convert(Varchar,Year(MS.ActivationDate))) as ActivationDate,
MS.CancellationRequestDate, P.Description AS MembershipTypeDescription,
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
  JOIN dbo.vClub C
       ON MS.ClubID = C.ClubID
  JOIN #Clubs CS
       ON C.ClubName = CS.ClubName OR CS.ClubName = 'All'
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
  JOIN dbo.vValRegion VR
       ON C.ValRegionID = VR.ValRegionID
  JOIN dbo.vMembershipType MST
       ON MS.MembershipTypeID = MST.MembershipTypeID
  JOIN dbo.vProduct P
       ON MST.ProductID = P.ProductID
  JOIN #MemType MT
       ON P.Description = MT.Description OR MT.Description = 'All'
  JOIN dbo.vValMembershipStatus VMSS
       ON MS.ValMembershipStatusID = VMSS.ValMembershipStatusID
  JOIN #MemStatus MSS
       ON VMSS.Description = MSS.Description OR MSS.Description = 'All'
  JOIN dbo.vValMemberType VMT
       ON M.ValMemberTypeID = VMT.ValMemberTypeID
  LEFT JOIN dbo.vPrimaryPhone PP
       ON (MS.MembershipID = PP.MembershipID)
  LEFT JOIN dbo.vMembershipPhone MSP
       ON (PP.MembershipID = MSP.MembershipID AND PP.ValPhoneTypeID = MSP.ValPhoneTypeID)
  LEFT JOIN dbo.vMembershipBalance MSB
       ON (MSB.MembershipID = MS.MembershipID) 
 WHERE --(C.ClubName IN (SELECT ClubName FROM #Clubs) OR
       --@ClubList = 'All') AND
       --(VMSS.Description IN (SELECT Description FROM #MemStatus) OR
       --@MemStatusList = 'All') AND
       VMSS.ValMembershipStatusID <> 1 AND
       VMT.Description = 'Primary' AND
       P.DepartmentID = 1 AND
       P.ProductID NOT  IN (88, 89, 90, 153) AND
       --(P.Description IN (SELECT Description FROM #MemType) OR
       --@MemTypeList = 'All') AND
       C.DisplayUIFlag = 1 AND
	   M.JoinDate >= @JoinDateStart AND
	   M.JoinDate <= @JoinDateEnd
	

DROP TABLE #Clubs
DROP TABLE #MemStatus
DROP TABLE #MemType
DROP TABLE #tmpList
DROP TABLE #PlanRate
DROP TABLE #ToUSDPlanRate

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END


