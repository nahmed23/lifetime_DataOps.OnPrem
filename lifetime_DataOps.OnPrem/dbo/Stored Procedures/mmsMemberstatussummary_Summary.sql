


CREATE    PROC [dbo].[mmsMemberstatussummary_Summary] (
  @ClubIDList VARCHAR(1000)
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

--
-- returns Member status info for the Memberstatussummary Brio bqy
--
-- Parameters: A | separated list of Club IDs
-- EXEC mmsMemberstatussummary_Summary '141'

CREATE TABLE #tmpList (StringField VARCHAR(50))
CREATE TABLE #Clubs (ClubID VARCHAR(50))

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

--INSERT INTO #Clubs EXEC procParseStringList @ClubList
   EXEC procParseStringList @ClubIDList
   INSERT INTO #Clubs (ClubID) SELECT StringField FROM #tmpList

/********  Foreign Currency Stuff ********/
DECLARE @ReportingCurrencyCode VARCHAR(15)
SET @ReportingCurrencyCode = 
(SELECT CASE WHEN COUNT(DISTINCT C.ValCurrencyCodeID) >=2 THEN 'USD' ELSE MAX(VCC.CurrencyCode) END AS ReportingCurrency
  FROM vClub C
  JOIN #Clubs ON C.ClubID = #Clubs.ClubID
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

--Added 02/2012 DBCR 06980 QC#1865
SELECT MTA.MembershipTypeID,
       VMTA.Description MembershipTypeGroup
  INTO #MembershipTypeGroups
  FROM vMembershipTypeAttribute MTA
  JOIN vValMembershipTypeAttribute VMTA ON MTA.ValMembershipTypeAttributeID = VMTA.ValMembershipTypeAttributeID
 WHERE VMTA.ValMembershipTypeAttributeID in (29,30,31)


DECLARE @FirstOfMonth DATETIME

SET @FirstOfMonth  =  CONVERT(DATETIME, SUBSTRING(CONVERT(VARCHAR,GETDATE(),112),1,6) + '01', 112)


SELECT MS.MembershipID, C.ClubName, MST.MembershipTypeID,
       VMS.Description AS MembershipStatusDescr, M.JoinDate, MS.ExpirationDate,
       MS.ValMembershipStatusID, M.FirstName,
       M.LastName, VR.Description AS RegionDescription,M.MemberID,
       GETDATE() AS QueryDate, 
	   Replace(SubString(Convert(Varchar, GETDATE()),1,3)+' '+LTRIM(SubString(Convert(Varchar, GETDATE()),5,DataLength(Convert(Varchar, GETDATE()))-12)),' '+Convert(Varchar,Year(GETDATE())),', '+Convert(Varchar,Year(GETDATE()))) as Today_Date,
	   MST.ShortTermMembershipFlag, P.Description AS MembershipTypeDescription,
       MST.ProductID, C.ClubID, CO.CorporateCode, CO.CompanyName,MS.CreatedDateTime,
  CASE WHEN( DATEDIFF(month,M.JoinDate,(ISNULL(MS.CreatedDateTime,CONVERT(DATETIME,'01/01/2000',101))))<-1)
       THEN 1
       ELSE 0
       END CreateDateJoinDateIssueFlag,
       #MembershipTypeGroups.MembershipTypeGroup ReportGrouping,--Added 02/2012 DBCR 06980 QC#1865
/******  Foreign Currency Stuff  *********/
	   VCC.CurrencyCode as LocalCurrencyCode,
       #PlanRate.PlanRate,
       @ReportingCurrencyCode as ReportingCurrencyCode,	   
	   CP.Price * #PlanRate.PlanRate as DuesPrice,	  
	   CP.Price as LocalCurrency_DuesPrice,	  
	   CP.Price * #ToUSDPlanRate.PlanRate as USD_DuesPrice	   
/***************************************/

  FROM dbo.vMember M
  JOIN dbo.vMembership MS
       ON M.MembershipID = MS.MembershipID
  JOIN dbo.vValMemberType VMT
       ON M.ValMemberTypeID = VMT.ValMemberTypeID
  JOIN dbo.vValMembershipStatus VMS
       ON VMS.ValMembershipStatusID = MS.ValMembershipStatusID
  JOIN dbo.vClub C
       ON MS.ClubID = C.ClubID
  JOIN #Clubs CS
       ON (C.ClubID = CS.ClubID or CS.ClubID = 'ALL')
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
  JOIN dbo.vMembershipType MST
       ON MS.MembershipTypeID = MST.MembershipTypeID
  LEFT JOIN #MembershipTypeGroups--Added 02/2012 DBCR 06980 QC#1865
       ON MST.MembershipTypeID = #MembershipTypeGroups.MembershipTypeID
  JOIN dbo.vValRegion VR
       ON C.ValRegionID = VR.ValRegionID
  JOIN dbo.vProduct P
       ON MST.ProductID = P.ProductID
  JOIN dbo.vClubProduct CP
       ON C.ClubID = CP.ClubID AND
       P.ProductID = CP.ProductID
  LEFT JOIN dbo.vCompany CO
       ON MS.CompanyID = CO.CompanyID
 WHERE VMT.ValMemberTypeID = 1 AND ----Primary Member Only
       C.DisplayUIFlag = 1 AND
       (MS.ExpirationDate IS NULL OR 
       MS.ExpirationDate >= @FirstOfMonth)

DROP TABLE #Clubs
DROP TABLE #tmpList
DROP TABLE #PlanRate
DROP TABLE #ToUSDPlanRate
DROP TABLE #MembershipTypeGroups

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END
