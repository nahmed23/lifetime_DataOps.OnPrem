



------------------------------------------------------------------------------------------------------------------------
/*	=============================================
Object:			dbo.mmsPackage_SalesDetail
Author:			
Create date: 	
Description:	This query returns information on package product sales within a selected date range.
Modified date:	11/17/2009 GRB: per QC# 4007, added MembershipID just before MemberID; 
					deploying 11/18/2009 via dbcr_5308
				10/7/2010 DBCR #6663 Updated Half_Session_Flag logic, added MembershipType product description
                02/28/2011 BSD: Hyperion month-end work.  Added @PartnerProgramList, Partner Program cursor, and join to #PartnerProgramMembers
                03/02/2011 BSD: Changed join to vEmployee to be Left Join
                04/28/2011 BSD: Added @MMSDeptIDList parameter QC#7066

Exec mmsPackage_SalesDetail 141, 'Apr 1, 2011', 'Apr 5, 2011','Medica - FitChoices|PreferredOne|Health Partners', '8|9'
	=============================================	*/

CREATE          PROCEDURE [dbo].[mmsPackage_SalesDetail](
       @ClubIDs VARCHAR(1000),
       @StartDate DATETIME,
       @EndDate DATETIME,
       @PartnerProgramList VARCHAR(2000), --2/28/2011 BSD
       @MMSDeptIDList VARCHAR(1000) -- 4/28/2011 BSD
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

CREATE TABLE #tmpList(StringField VARCHAR(50))

---- Parse the ClubIDs into a temp table
EXEC procParseIntegerList @ClubIDs
CREATE TABLE #Clubs(ClubID INT)
INSERT INTO #Clubs(ClubID) SELECT StringField FROM #tmpList

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

--Added 2/28/2011 BSD
TRUNCATE TABLE #tmpList
CREATE TABLE #PartnerPrograms (PartnerProgram Varchar(50))
EXEC procParseStringList @PartnerProgramList
INSERT INTO #PartnerPrograms (PartnerProgram) SELECT StringField FROM #tmpList

--Added 4/28/2011 BSD
TRUNCATE TABLE #tmpList
CREATE TABLE #DepartmentIDs (DepartmentID INT)
IF @MMSDeptIDList = 'All'
 BEGIN
  INSERT INTO #DepartmentIDS (DepartmentID) SELECT DepartmentID FROM vDepartment
 END
ELSE
 BEGIN
  EXEC procParseIntegerList @MMSDeptIDList
  INSERT INTO #DepartmentIDs SELECT StringField FROM #tmpList
 END

--This cursor query returns MemberID and a comma delimited list of Partner Programs 
--used for Member Reimbursement within @StarDate and @EndDate
CREATE TABLE #PartnerProgramMembers (MemberID INT, PartnerProgramList VARCHAR(2000))

DECLARE @CursorMemberID INT,
        @CursorPartnerProgramName VARCHAR(2000),
        @CurrentMemberID INT

DECLARE PartnerProgram_Cursor CURSOR LOCAL READ_ONLY FOR
SELECT DISTINCT MR.MemberID, RP.ReimbursementProgramName
FROM vMemberReimbursement MR
JOIN vReimbursementProgram RP
  ON MR.ReimbursementProgramID = RP.ReimbursementProgramID
JOIN #PartnerPrograms PP
  ON RP.ReimbursementProgramName = PP.PartnerProgram
WHERE MR.EnrollmentDate <= @EndDate
  AND (MR.TerminationDate >= @StartDate OR MR.TerminationDate IS NULL)
ORDER BY MR.MemberID, RP.ReimbursementProgramName

SET @CurrentMemberID = 0

OPEN PartnerProgram_Cursor
FETCH NEXT FROM PartnerProgram_Cursor INTO @CursorMemberID, @CursorPartnerProgramName
WHILE (@@FETCH_STATUS = 0)
  BEGIN
    IF @CursorMemberID <> @CurrentMemberID
      BEGIN
        INSERT INTO #PartnerProgramMembers (MemberID, PartnerProgramList) VALUES (@CursorMemberID,@CursorPartnerProgramName)
        SET @CurrentMemberID = @CursorMemberID
      END
    ELSE
      BEGIN
        UPDATE #PartnerProgramMembers
        SET PartnerProgramList = PartnerProgramList+', '+@CursorPartnerProgramName
        WHERE MemberID = @CursorMemberID
      END
    FETCH NEXT FROM PartnerProgram_Cursor INTO @CursorMemberID, @CursorPartnerProgramName
  END

CLOSE PartnerProgram_Cursor
DEALLOCATE PartnerProgram_Cursor

SELECT E.Employeeid,E.Firstname AS EmployeeFirstname, E.Lastname AS EmployeeLastname,
P.Productid, P.Description AS ProductDescription, 
M.Memberid, M.Firstname AS MemberFirstname, 
M.Lastname AS MemberLastname,  VPS.Description AS PackageStatusDescription, 
PKG.Packageid,SC.Clubname AS SaleClub, SC.Clubid AS SaleClubid,
R.Description AS RegionDescription,PKG.Createddatetime as Createddatetime_Sort,
Replace(Substring(convert(varchar,PKG.CreatedDateTime,100),1,6)+', '+Substring(convert(varchar,PKG.CreatedDateTime,100),8,10)+' '+Substring(convert(varchar,PKG.CreatedDateTime,100),18,2),'  ',' ') as CreatedDateTime,
PKG.Numberofsessions,
VDS.Description AS DrawerStatusDescription, MSC.ClubName AS MembershipHomeClub,
EC.ClubName AS EmployeeHomeClub,
CASE                                               
    WHEN P.Description LIKE '%30 minute%'          -- Updated 10/7/2010
         THEN 1                                   
         ELSE 0                                       
END Half_Session_Flag,
M.MembershipID,		-- added 11/17/2009 GRB
P2.Description as MembershipType,   -- Added 10/7/2010
CASE WHEN @PartnerProgramList = '< Do Not Limit By Partner Program >' --2/28/2011 BSD 
          THEN 'Not limited by Partner Program' --2/28/2011 BSD 
     ELSE PPM.PartnerProgramList  --2/28/2011 BSD 
END AS SelectedPartnerPrograms, --2/28/2011 BSD 
/******  Foreign Currency Stuff  *********/
	   VCC.CurrencyCode as LocalCurrencyCode,
       #PlanRate.PlanRate,
       @ReportingCurrencyCode as ReportingCurrencyCode,
	   PKG.Pricepersession * #PlanRate.PlanRate as Pricepersession,	   
	   PKG.Pricepersession as LocalCurrency_Pricepersession,	  
	   PKG.Pricepersession * #ToUSDPlanRate.PlanRate as USD_Pricepersession    	
/***************************************/

FROM dbo.vPackage PKG
JOIN dbo.vClub SC
    ON PKG.Clubid = SC.Clubid
/********** Foreign Currency Stuff **********/
  JOIN vValCurrencyCode VCC
       ON SC.ValCurrencyCodeID = VCC.ValCurrencyCodeID
  JOIN #PlanRate
       ON VCC.CurrencyCode = #PlanRate.FromCurrencyCode
      AND YEAR(PKG.Createddatetime) = #PlanRate.PlanYear
  JOIN #ToUSDPlanRate
       ON VCC.CurrencyCode = #ToUSDPlanRate.FromCurrencyCode
      AND YEAR(PKG.Createddatetime) = #ToUSDPlanRate.PlanYear
/*******************************************/
JOIN #Clubs tC
    ON SC.Clubid = tC.ClubID
JOIN dbo.vValRegion R
    ON SC.Valregionid = R.ValRegionID
LEFT JOIN dbo.vEmployee E --3/2/2011 BSD LEFT JOIN
    ON PKG.Employeeid = E.Employeeid
LEFT JOIN dbo.vClub EC --3/2/2011 BSD Left Join
    ON E.ClubID = EC.ClubID -----To get Employee Home Club
JOIN dbo.vMember M
    ON PKG.Memberid = M.Memberid
JOIN dbo.vMembership MS
    ON M.MembershipID = MS.MembershipID 
JOIN dbo.vClub MSC
    ON MS.ClubID = MSC.ClubID ---- To get Member's Home Club
JOIN dbo.vProduct P
    ON PKG.Productid = P.Productid
JOIN #DepartmentIDs --4/28/2011 BSD
    ON P.DepartmentID = #DepartmentIDs.DepartmentID --4/28/2011 BSD
JOIN dbo.vValpackagestatus VPS
    ON PKG.Valpackagestatusid = VPS.Valpackagestatusid
JOIN dbo.vMmstran MST
    ON PKG.Mmstranid = MST.Mmstranid
JOIN dbo.vDrawerActivity DA
    ON MST.Draweractivityid = DA.Draweractivityid
JOIN dbo.vValdrawerstatus VDS
    ON DA.Valdrawerstatusid = VDS.Valdrawerstatusid
JOIN dbo.vMembershipType MT      -- Added 10/7/2010
	ON MS.MembershipTypeID=MT.MembershipTypeID      -- Added 10/7/2010
JOIN dbo.vProduct P2      -- Added 10/7/2010
	ON MT.ProductID=P2.ProductID      -- Added 10/7/2010
LEFT JOIN #PartnerProgramMembers PPM --2/28/2011 BSD
    ON M.MemberID = PPM.MemberID --2/28/2011 BSD
WHERE PKG.Createddatetime >= @StartDate 
  AND PKG.Createddatetime <= @EndDate
  AND ISNULL(PPM.MemberID,'-999') = CASE WHEN @PartnerProgramList = '< Do Not Limit By Partner Program >' --2/28/2011 BSD
                                               THEN ISNULL(PPM.MemberID,'-999') --2/28/2011 BSD
                                          ELSE M.MemberID END --2/28/2011 BSD

DROP TABLE #Clubs
DROP TABLE #tmpList
DROP TABLE #PartnerPrograms
DROP TABLE #PartnerProgramMembers
DROP TABLE #DepartmentIDs
DROP TABLE #PlanRate
DROP TABLE #ToUSDPlanRate

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END

