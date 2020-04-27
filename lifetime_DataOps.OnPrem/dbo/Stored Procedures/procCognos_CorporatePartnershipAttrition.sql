--Exec procCognos_CorporatePartnershipAttrition '1/1/2016','2/1/2017','Brian Conaway'
CREATE PROC [dbo].[procCognos_CorporatePartnershipAttrition] (
        @StartDate DATETIME
	  , @EndDate DATETIME
	  , @BDM VARCHAR(1000)
)
AS
BEGIN 
SET XACT_ABORT ON
SET NOCOUNT ON

--@Start and @End Dates of when Membership Terminiate
--Active Members as of @EndDate

--DECLARE @StartDate DATETIME  = '5/1/2017'
--DECLARE @EndDate DATETIME = '5/19/2017'

SELECT CompanyID, AccountOwner, CorporateCode
INTO #Company
FROM vCompany
WHERE vCompany.OpportunityRecordType = 'Corporate Partnership Opportunity'


CREATE TABLE #tmpList (StringField VARCHAR(100))

CREATE TABLE #BDM (AccountOwner VARCHAR(100))
EXEC procParseStringList @BDM
INSERT INTO #BDM (AccountOwner) SELECT StringField FROM #tmpList
TRUNCATE TABLE #tmpList

Select 
 M.MembershipID
, M.MemberID
, CO.CompanyID
, Rp.ReimbursementProgramID
, CO.CorporateCode
, MS.ValMembershipStatusID
, 'Active' as MembershipStatus

INTO #CompanyMembers
From vMember M
Join vValMemberType VMT
  On M.ValMemberTypeID = VMT.ValMemberTypeID
Join vMemberReimbursement MR
  On M.MemberID = MR.MemberID
Join vReimbursementProgram RP
  On MR.ReimbursementProgramID = RP.ReimbursementProgramID
Join vCompany CO
  On RP.CompanyID = CO.CompanyID
Join vMembership MS
  On M.MembershipID = MS.MembershipID
JOIN #Company #C
  ON (Convert(varchar,RP.CompanyID) = Convert(Varchar,#C.CompanyID)
    OR #C.CompanyID = '0')
JOIN #BDM
  ON #BDM.AccountOwner = CO.AccountOwner

Where 
 (MS.ExpirationDate > @EndDate OR ISNull(MS.ExpirationDate,'1/1/1900')='1/1/1900') 
AND CO.OpportunityRecordType = 'Corporate Partnership Opportunity'

-----------------------------------------   Terminated Coprorate Partnership Opportunity Membmerships----------------------------
UNION
Select 
 M.MembershipID
, M.MemberID
, CO.CompanyID
, Rp.ReimbursementProgramID
, CO.CorporateCode
, MS.ValMembershipStatusID
, 'Terminated' as MembershipStatus

From vMember M
Join vValMemberType VMT
  On M.ValMemberTypeID = VMT.ValMemberTypeID
Join vMemberReimbursement MR
  On M.MemberID = MR.MemberID
Join vReimbursementProgram RP
  On MR.ReimbursementProgramID = RP.ReimbursementProgramID
Join vCompany CO
  On RP.CompanyID = CO.CompanyID
Join vMembership MS
  On M.MembershipID = MS.MembershipID
JOIN #Company #C
  ON (Convert(varchar,RP.CompanyID) = Convert(Varchar,#C.CompanyID)
    OR #C.CompanyID = '0')
JOIN #BDM
  ON #BDM.AccountOwner = CO.AccountOwner

Where 
MS.ExpirationDate BETWEEN @StartDate AND @EndDate
AND CO.OpportunityRecordType = 'Corporate Partnership Opportunity'
AND MS.CancellationRequestDate != MS.ExpirationDate    -----14 Day Terminations

   CREATE TABLE #LastPartnerProgamVersionInPeriod (
   MemberID INT,
   ReimbursementProgramID INT,
   ReimbursementProgramName VARCHAR(50),
   MemberReimbursementID INT,
   CompanyID INT,
   AccountOwner VARCHAR(100),
   MembershipStatus VARCHAR(100),
   Match Float
   )
   
   INSERT INTO #LastPartnerProgamVersionInPeriod
   SELECT 
   MR.MemberID,
       RP.ReimbursementProgramID,
       RP.ReimbursementProgramName,
       MAX(MR.MemberReimbursementID),
	   #C.CompanyID,
	   #C.AccountOwner,
	   #CM.MembershipStatus,
	   ISNULL(CD.Match,0) as Match
  FROM #CompanyMembers #CM
  JOIN vMemberReimbursement MR
    ON #CM.MemberID = MR.MemberID
   AND (MR.EnrollmentDate <= @EndDate +1)
   AND (MR.TerminationDate > @StartDate OR ISNull(MR.TerminationDate,'1/1/1900')='1/1/1900')
  JOIN vReimbursementProgram RP
    ON MR.ReimbursementProgramID = RP.ReimbursementProgramID
  JOIN #Company #C
    ON (Convert(varchar,RP.CompanyID) = Convert(Varchar,#C.CompanyID)
    OR #C.CompanyID = '0')
--LEFT JOIN Sandbox_Int.rep.CorporateDiscount CD                -------QA Location
--  ON CD.CompanyID = #C.CorporateCode
LEFT JOIN TemporaryImport.dbo.CorporateDiscount CD            -------PROD Location  
  ON CD.CompanyID = #C.CorporateCode

 GROUP BY MR.MemberID, 
          RP.ReimbursementProgramID, 
          RP.ReimbursementProgramName, 
		  #C.CompanyID,
		  #C.AccountOwner,
		  #CM.MembershipStatus,
		  CD.Match

--------------------------------------LTF Attrition  NON corporate Partnership Memberships----------------------------------------------------
Select 
 MS.MembershipID
, 0 as MemberID
, CO.CompanyID
, 0 as ReimbursementProgramID
, CO.CorporateCode
, MS.ValMembershipStatusID
, 'Terminated' as MembershipStatus

INTO #TerminatedNonCorpPartnershipOpp
From vMember M
Join vMembership MS
  On M.MembershipID = MS.MembershipID
LEFT JOIN vCompany CO
  ON MS.CompanyID = CO.CompanyID

Where 
MS.ExpirationDate BETWEEN @StartDate AND @EndDate
AND (CO.OpportunityRecordType != 'Corporate Partnership Opportunity' OR CO.OpportunityRecordType IS NULL)
AND MS.CancellationRequestDate != MS.ExpirationDate    -----14 Day Terminations

UNION 

Select 
 MS.MembershipID
, 0 as MemberID
, CO.CompanyID
, 0 as ReimbursementProgramID
, CO.CorporateCode
, MS.ValMembershipStatusID
, 'Active' as MembershipStatus

FROM vMembership MS
LEFT JOIN vCompany CO
  ON MS.CompanyID = CO.CompanyID

Where 
(MS.ExpirationDate > @EndDate OR ISNull(MS.ExpirationDate,'1/1/1900')='1/1/1900') 
AND (CO.OpportunityRecordType != 'Corporate Partnership Opportunity' OR CO.OpportunityRecordType IS NULL)

---------------------------------------------------- Results -------------------------------------


SELECT    --------------------------Corp Partnerships
LPPVP.AccountOwner,
LPPVP.Match,
SUM(Case WHEN LPPVP.MembershipStatus = 'Active' Then 1 Else 0 End) as ActiveCount,
SUM(Case WHEN LPPVP.MembershipStatus = 'Terminated' Then 1 Else 0 End) as TerminatedCount,
CAST(SUM(Case WHEN LPPVP.MembershipStatus = 'Terminated' Then 1 Else 0 End)as FLOAT)  / CAST(SUM(Case WHEN LPPVP.MembershipStatus = 'Active' Then 1 Else 0 End) as FLOAT) as Attrition

FROM #LastPartnerProgamVersionInPeriod LPPVP

GROUP BY LPPVP.AccountOwner
		, LPPVP.Match

UNION   

SELECT   -----LTF Non Corp Partnerships
'LTFAverage' as AccountOwner,
0 as Match,
SUM(Case WHEN T.MembershipStatus = 'Active' Then 1 Else 0 End) as ActiveCount,
SUM(Case WHEN T.MembershipStatus = 'Terminated' Then 1 Else 0 End) as TerminatedCount,
CAST(SUM(Case WHEN T.MembershipStatus = 'Terminated' Then 1 Else 0 End)as FLOAT)  / CAST(SUM(Case WHEN T.MembershipStatus = 'Active' Then 1 Else 0 End) as FLOAT) as Attrition
FROM #TerminatedNonCorpPartnershipOpp T

ORDER by LPPVP.AccountOwner
		, LPPVP.Match


DROP TABLE #Company
DROP TABLE #CompanyMembers
DROP TABLE #LastPartnerProgamVersionInPeriod
DROP TABLE #tmpList
DROP TABLE #TerminatedNonCorpPartnershipOpp
DROP TABLE #BDM


END
