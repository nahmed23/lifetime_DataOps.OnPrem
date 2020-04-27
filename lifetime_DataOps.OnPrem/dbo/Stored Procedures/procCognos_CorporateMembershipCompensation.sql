CREATE PROC [dbo].[procCognos_CorporateMembershipCompensation] (
        @StartDate DATETIME
	  , @EndDate DATETIME
	  , @BDM VARCHAR(8000)
)

AS
BEGIN 
SET XACT_ABORT ON
SET NOCOUNT ON

IF 1=0 BEGIN
       SET FMTONLY OFF
     END

--DECLARE @StartDate DATETIME
--DECLARE @EndDate DATETIME
--SET @StartDate = '7/1/2019'
--SET @EndDate = '7/15/2019'
--DECLARE @BDM VARCHAR(8000) = 'Gregory Hettrick|Brian Conaway'

IF OBJECT_ID('tempdb.dbo.#tmpList', 'U') IS NOT NULL DROP TABLE #tmpList;
IF OBJECT_ID('tempdb.dbo.#BDM', 'U') IS NOT NULL DROP TABLE #BDM;
IF OBJECT_ID('tempdb.dbo.#CompanyIDList', 'U') IS NOT NULL DROP TABLE #CompanyIDList;
IF OBJECT_ID('tempdb.dbo.#Clubs', 'U') IS NOT NULL DROP TABLE #Clubs;
IF OBJECT_ID('tempdb.dbo.#CompanyMembers', 'U') IS NOT NULL DROP TABLE #CompanyMembers;
IF OBJECT_ID('tempdb.dbo.#CompanyMembershipsRanked', 'U') IS NOT NULL DROP TABLE #CompanyMembershipsRanked;
IF OBJECT_ID('tempdb.dbo.#CompanyMembershipClubs', 'U') IS NOT NULL DROP TABLE #CompanyMembershipClubs;

DECLARE @ReportRunDateTime VARCHAR(21)
SET @ReportRunDateTime = Replace(Substring(convert(varchar,GetDate(),100),1,6)+', '+Substring(convert(varchar,GetDate(),100),8,10)+' '+Substring(convert(varchar,GetDate(),100),18,2),'  ',' ')

CREATE TABLE #tmpList (StringField VARCHAR(100))

CREATE TABLE #BDM (AccountOwner VARCHAR(50))
EXEC procParseStringList @BDM
INSERT INTO #BDM (AccountOwner) SELECT CAST(StringField as VARCHAR) StringField FROM #tmpList
TRUNCATE TABLE #tmpList

SELECT C.CompanyID
INTO #CompanyIDList
FROM vCompany C
WHERE C.OpportunityRecordType IN ('Corporate Partnership Opportunity','LT Work')
  AND C.ActiveAccountFlag = 1

SELECT DISTINCT ClubID as ClubID
  INTO #Clubs
  FROM vClub Club

 --- Gather list of all memberships with selected corporate affiliation - Membership Company or Reimbursement Program Company
 --- within the selected clubs and Membership Types

----Create a Temp table for Corp Discounts and their most recent Discounts

SELECT
cd.CorporateCode
,MIN(ABS(DATEDIFF(DD,cd.DiscountAsOfDate,GETDATE()))) MinDate
INTO #Corpdiscountmindate
FROM dbo.CorporateDiscountwDate cd
GROUP BY cd.CorporateCode

SELECT cd.CorporateCode
,t.DiscountAsOfDate
,t.ChicagoCorporateDiscount
INTO #corpdiscount
FROM #Corpdiscountmindate cd
INNER JOIN
    (
        SELECT CorporateCode,SUM(ChicagoCorporateDiscount) ChicagoCorporateDiscount ,DiscountAsOfDate,MIN(ABS(DATEDIFF(DD,DiscountAsOfDate,GETDATE()))) AS MinDate
        FROM dbo.CorporateDiscountwDate
        GROUP BY CorporateCode,DiscountAsOfDate
    ) t ON cd.CorporateCode = t.CorporateCode AND cd.MinDate = t.MinDate

   ---- returns one record for each member with an active a reimb. program company
SELECT M.MembershipID
, MS.MembershipTypeID
, MS.CurrentPrice
, MS.ValMembershipStatusID
, M.MemberID
, CO.CompanyID
--, CAST('1/1/1900' as DATETIME) InsertedDateTime  --Comment out for Prod
, CO.InsertedDateTime  --Not in Dev/QA
, convert(datetime,convert(varchar,IsNull(MS.CreatedDateTime,'1/1/1900'),110),110) AS MembershipCreatedDate
, MS.ClubID
, M.ValMemberTypeID
, MS.AdvisorEmployeeID
, MS.SalesForce_Opportunity_ID
, corpdiscount.ChicagoCorporateDiscount

INTO #CompanyMembers
FROM vMember M
JOIN vMemberReimbursement MR
  ON M.MemberID = MR.MemberID
JOIN vReimbursementProgram RP
  ON MR.ReimbursementProgramID = RP.ReimbursementProgramID
JOIN vCompany CO
  ON RP.CompanyID = CO.CompanyID
JOIN vMembership MS
  ON M.MembershipID = MS.MembershipID
JOIN vValMembershipStatus VMS
  ON MS.ValMembershipStatusID = VMS.ValMembershipStatusID
JOIN #Clubs #Clubs
  ON MS.ClubID = #Clubs.ClubID
JOIN #CompanyIDList #C
  ON (Convert(varchar,CO.CompanyID) = Convert(Varchar,#C.CompanyID)
    OR #C.CompanyID = '0')
JOIN #BDM
  ON #BDM.AccountOwner = CO.AccountOwner
 LEFT JOIN #Corpdiscount corpdiscount
    ON CAST(corpdiscount.CorporateCode as char(50)) = CO.CorporateCode
  
WHERE CAST(MR.EnrollmentDate as Date) <= @EndDate
  AND ISNull(MR.TerminationDate,'1/1/2100') > @StartDate
  AND CAST(MS.CreatedDateTime as Date) BETWEEN @StartDate AND @EndDate
  AND CO.OpportunityRecordType IN ('Corporate Partnership Opportunity','LT Work')

  GROUP BY 
  M.MembershipID
, MS.MembershipTypeID
, MS.CurrentPrice
, MS.ValMembershipStatusID
, M.MemberID
, CO.CompanyID
--, CAST('1/1/1900' as DATETIME) InsertedDateTime  --Comment out for Prod
, CO.InsertedDateTime  --Not in Dev/QA
, MS.CreatedDateTime
, MS.ClubID
, M.ValMemberTypeID
, MS.AdvisorEmployeeID
, MS.SalesForce_Opportunity_ID
, corpdiscount.ChicagoCorporateDiscount
	

UNION    

  ------ returns primary member for all memberships which have a membership company affiliation
  SELECT 
  MS.MembershipID
  , MS.MembershipTypeID
  , MS.CurrentPrice
  , MS.ValMembershipStatusID
  , M.MemberID
  , CO.CompanyID
  , CAST('1/1/1900' as DATETIME) InsertedDateTime
--  , CO.InsertedDateTime  Not in DEv/QA
  , convert(datetime,convert(varchar,IsNull(MS.CreatedDateTime,'1/1/1900'),110),110) AS MembershipCreatedDate
  , MS.ClubID
  , M.ValMemberTypeID
  , MS.AdvisorEmployeeID
  , MS.SalesForce_Opportunity_ID
  , Corpdiscount.ChicagoCorporateDiscount

  FROM vMember M
  JOIN vMembership MS WITH (NOLOCK)
    ON M.MembershipID = MS.MembershipID
  JOIN vValMembershipStatus VMS
    ON MS.ValMembershipStatusID = VMS.ValMembershipStatusID
  JOIN vCompany CO
    ON MS.CompanyID = CO.CompanyID
  JOIN #Clubs #Clubs
    ON MS.ClubID = #Clubs.ClubID
  JOIN #CompanyIDList #C
    ON (Convert(varchar,CO.CompanyID) = Convert(Varchar,#C.CompanyID)
    OR #C.CompanyID = '0')
  JOIN vMembershipType MT
    ON MS.MembershipTypeID = MT.MembershipTypeID
  JOIN vValMembershipTypeFamilyStatus as FamilyStatus
    ON MT.ValMembershipTypeFamilyStatusID = FamilyStatus.ValMembershipTypeFamilyStatusID
  JOIN #BDM
    ON #BDM.AccountOwner = CO.AccountOwner
  LEFT JOIN #Corpdiscount corpdiscount
    ON CAST(corpdiscount.CorporateCode as char(50)) = CO.CorporateCode

 
 WHERE 
    M.ValMemberTypeID = 1
	AND CAST(MS.CreatedDateTime as Date) BETWEEN @StartDate AND @EndDate
	AND CO.OpportunityRecordType IN ('Corporate Partnership Opportunity','LT Work')

  ---- Rank is assigned based on ValMemberType order for each Membership to enable selecting just 1 record per membership		
SELECT MembershipID,
       MembershipTypeID,
	   CurrentPrice,
	   ValMembershipStatusID,
    --   MemberID, 
	   CompanyID,
	   InsertedDateTime,
	   ClubID,
	   ValMemberTypeID,	
	   AdvisorEmployeeID,
	   MembershipCreatedDate,
	   SalesForce_Opportunity_ID,
	   ChicagoCorporateDiscount,
       RANK() OVER (PARTITION BY MembershipID				
                        ORDER BY ValMemberTypeID) MembershipMemberRank				
  INTO #CompanyMembershipsRanked				
  FROM #CompanyMembers	

  ----- find Club IDs for company memberships
SELECT ClubID
 INTO #CompanyMembershipClubs
FROM #CompanyMembershipsRanked
 GROUP BY ClubID

SELECT	 CO.AccountOwner
		, BDMClubs.BDM ClubBDM
		, CAST(Co.CompanyID as varchar) CompanyID
		, CO.CorporateCode
		, CO.OpportunityRecordType
     	, CO.CompanyName
	--	, CAST('1/1/1900' as DATETIME) PartnershipCreated  --Comment oout For PRod
		, CO.InsertedDateTime PartnershipCreated   -- Not in Dev/QA
		, MS.MembershipID
		, MT.DisplayName as MembershipType
		, C.Clubname
		, MS.ClubID
		, IsNull(MS.CurrentPrice,0)as MonthlyDues
		, ISNULL(MS.ChicagoCorporateDiscount,0) as Match
		, IsNull(MS.CurrentPrice,0) - isnull(MS.ChicagoCorporateDiscount,0) as CMD
		, MS.MembershipCreatedDate as JoinDate
		, CASE WHEN DATEDIFF(MM,RP.InsertedDateTime,MS.MembershipCreatedDate) > 12     ----- Not in Dev/QA
			THEN 'N' Else 'Y'
			END as CreatedInLast12Months 
		, @StartDate as HeaderStart
		, @EndDate As HeaderEnd
		 	 	 	 	  
  FROM #CompanyMembershipsRanked MS
  JOIN vClub C
    ON MS.ClubID=C.ClubID
  JOIN vCompany CO
    ON MS.CompanyID=CO.CompanyID
  JOIN vMembershipType MT
    ON MS.MembershipTypeID = MT.MembershipTypeID
  LEFT JOIN dbo.BDMClubs 
    ON BDMClubs.ClubID = C.ClubID
  LEFT JOIN [dbo].[vReimbursementProgram] RP
    ON RP.CompanyID = CO.CompanyID


WHERE MS.MembershipMemberRank = 1
  AND CO.ActiveAccountFlag = 1
  AND MT.DisplayName NOT LIKE 'Trade%'    --Eliminate Any Trade out Memberships
  	   
GROUP BY 	   
	 CO.AccountOwner
	, BDMClubs.BDM
	, Co.CompanyID
	, CO.CorporateCode
	, CO.CompanyName
	, CO.InsertedDateTime
	, MS.MembershipID
	, MS.CurrentPrice
	, CO.OpportunityRecordType
	, MS.ChicagoCorporateDiscount
	, MT.DisplayName
	, C.Clubname
	, MS.ClubID
	, MS.MembershipCreatedDate
	, RP.InsertedDateTime

ORDER BY 
 CO.AccountOwner
,Co.CompanyName

DROP TABLE #Corpdiscountmindate
DROP TABLE #Corpdiscount
DROP TABLE #tmpList
DROP TABLE #BDM
DROP TABLE #CompanyIDList
DROP TABLE #Clubs
DROP TABLE #CompanyMembers
DROP TABLE #CompanyMembershipsRanked
DROP TABLE #CompanyMembershipClubs


END
