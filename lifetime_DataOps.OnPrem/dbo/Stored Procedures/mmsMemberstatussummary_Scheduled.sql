
CREATE         PROC [dbo].[mmsMemberstatussummary_Scheduled](
               @RegionList VARCHAR(1000))
AS
BEGIN 
SET XACT_ABORT ON
SET NOCOUNT ON

-- returns Member status info - called by the region specific stored procedures
--
-- Parameters:  List of regions separated by |
-- EXEC mmsMemberstatussummary_Scheduled 'West-Mountain|West-Desert|East-OhioIN'

CREATE TABLE #tmpList (StringField VARCHAR(50))
CREATE TABLE #Regions (RegionName VARCHAR(50))

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

EXEC procParseStringList @RegionList
INSERT INTO #Regions (RegionName) SELECT StringField FROM #tmpList
TRUNCATE TABLE #tmpList

/********  Foreign Currency Stuff ********/
DECLARE @ReportingCurrencyCode VARCHAR(15)
SET @ReportingCurrencyCode = 
(SELECT CASE WHEN COUNT(DISTINCT C.ValCurrencyCodeID) >=2 THEN 'USD' ELSE MAX(VCC.CurrencyCode) END AS ReportingCurrency
  FROM vClub C 
  JOIN vValRegion VR ON C.ValRegionID = VR.ValRegionID
  JOIN #Regions ON VR.Description = #Regions.RegionName
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

DECLARE @FirstOfMonth DATETIME
SET @FirstOfMonth  = CONVERT(DATETIME, SUBSTRING(CONVERT(VARCHAR,GETDATE(),112),1,6) + '01', 112)

SELECT ms.MembershipID,
	CASE WHEN mta.MembershipTypeID IS NOT NULL AND ms.ClubID = 160 THEN 220 --Cary
		 WHEN mta.MembershipTypeID IS NOT NULL AND ms.ClubID = 159 THEN 219 --Dublin
		 WHEN mta.MembershipTypeID IS NOT NULL AND ms.ClubID = 40 THEN 218  --Easton
		 WHEN mta.MembershipTypeID IS NOT NULL AND ms.ClubID = 30 THEN 214  --Indianapolis
		 ELSE ms.ClubID END ClubID,
	ms.ExpirationDate,
	ms.CompanyID,
	ms.MembershipTypeID,
	ms.ValMembershipStatusID,
	ms.CreatedDateTime
INTO #Membership
FROM vMembership ms WITH (NOLOCK)
LEFT JOIN vMembershipTypeAttribute mta WITH (NOLOCK)
  ON mta.MembershipTypeID = ms.MembershipTypeID
 AND mta.ValMembershipTypeAttributeID = 28 --Acquisition
WHERE (ms.ExpirationDate IS NULL OR ms.ExpirationDate >= @FirstOfMonth) --limit from result query

--vClubProduct
SELECT cp.ClubProductID,
	   CASE WHEN mta.MembershipTypeID IS NOT NULL AND cp.ClubID = 160 THEN 220 --Cary
	        WHEN mta.MembershipTypeID IS NOT NULL AND cp.ClubID = 159 THEN 219 --Dublin
		    WHEN mta.MembershipTypeID IS NOT NULL AND cp.ClubID = 40 THEN 218  --Easton
		    WHEN mta.MembershipTypeID IS NOT NULL AND cp.ClubID = 30 THEN 214  --Indianapolis
		    ELSE cp.ClubID END ClubID,
	   cp.ProductID,cp.Price
 INTO #ClubProduct
 FROM vClubProduct cp WITH (NOLOCK)
LEFT JOIN vMembershipTypeAttribute mta WITH (NOLOCK)
  ON mta.MembershipTypeID = cp.ProductID
 AND mta.ValMembershipTypeAttributeID = 28 --Acquisition
UNION
SELECT cp.ClubProductID,
	   CASE WHEN cp.ClubID = 160 THEN 220 --Cary
	        WHEN cp.ClubID = 159 THEN 219 --Dublin
		    WHEN cp.ClubID = 40 THEN 218  --Easton
		    WHEN cp.ClubID = 30 THEN 214  --Indianapolis
		    ELSE cp.ClubID END ClubID,
	   cp.ProductID,cp.Price
 FROM vClubProduct cp WITH (NOLOCK)
 WHERE cp.ClubID in (30,40,159,160)
   AND cp.ProductID in (1497,3100)

--Added 02/2012 DBCR 06980 QC#1865
SELECT MTA.MembershipTypeID,
       VMTA.Description MembershipTypeGroup
  INTO #MembershipTypeGroups
  FROM vMembershipTypeAttribute MTA
  JOIN vValMembershipTypeAttribute VMTA ON MTA.ValMembershipTypeAttributeID = VMTA.ValMembershipTypeAttributeID
 WHERE VMTA.ValMembershipTypeAttributeID in (29,30,31)

SELECT MS.MembershipID, C.ClubName, MST.MembershipTypeID,
       VMS.Description AS MembershipStatusDescr, M.JoinDate, MS.ExpirationDate,
       MS.ValMembershipStatusID, M.FirstName,
       M.LastName,VR.Description AS RegionDescription,M.MemberID,
       GetDate() QueryDate, 
	   Replace(SubString(Convert(Varchar, GETDATE()),1,3)+' '+LTRIM(SubString(Convert(Varchar, GETDATE()),5,DataLength(Convert(Varchar, GETDATE()))-12)),' '+Convert(Varchar,Year(GETDATE())),', '+Convert(Varchar,Year(GETDATE()))) as Todays_Date,
       MST.ShortTermMembershipFlag, P.Description AS MembershipTypeDescription,
       MST.ProductID, C.ClubID, CO.CorporateCode, M.MemberID AS PrimaryMemberID,
       CO.CompanyName, MS.CreatedDateTime,
       CASE WHEN(DATEDIFF(month,M.JoinDate,(ISNULL(MS.CreatedDateTime,CONVERT(DATETIME,'01/01/2000',101))))<-1)
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
  JOIN #Membership MS
       ON M.MembershipID = MS.MembershipID
  JOIN dbo.vValMemberType VMT
       ON M.ValMemberTypeID = VMT.ValMemberTypeID
  JOIN dbo.vValMembershipStatus VMS
       ON VMS.ValMembershipStatusID = MS.ValMembershipStatusID
  JOIN dbo.vClub C
       ON MS.ClubID = C.ClubID
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
  JOIN #ClubProduct CP
       ON C.ClubID = CP.ClubID AND
       P.ProductID = CP.ProductID
  LEFT JOIN dbo.vCompany CO
       ON MS.CompanyID = CO.CompanyID
  JOIN #Regions R
       ON R.RegionName = VR.Description 
 WHERE VMT.ValMemberTypeID = 1 AND
       C.DisplayUIFlag = 1 AND
       (MS.ExpirationDate IS NULL OR 
       MS.ExpirationDate >=@FirstOfMonth)

DROP TABLE #tmpList
DROP TABLE #Regions
DROP TABLE #PlanRate
DROP TABLE #ToUSDPlanRate
drop table #membership
drop table #clubproduct
DROP TABLE #MembershipTypeGroups

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END
