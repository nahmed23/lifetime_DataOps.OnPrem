

------------------------------------------------------------------------------------------------------------------------
/*	=============================================
Object:			dbo.mmsPackage_Adjustments
Author:			
Create date: 	
Description:	Returns listing of Package Product session adjustments within a selected date range
Modified date:	11/17/2009 GRB: per QC# 4007, added MembershipID just before MemberID; 
					deploying 11/18/2009 via dbcr_5308
                02/28/2011 BSD: Hyperion month-end work.  Added @PartnerProgramList, Partner Program cursor, and join to #PartnerProgramMembers
                04/28/2011 BSD: Added @MMSDeptIDList parameter QC#7066

Exec mmsPackage_Adjustments '141|14|151', 'Jan 1, 2011', 'Jan 30, 2013', '< Do Not Limit By Partner Program >', 'All'
=============================================	*/

CREATE        PROCEDURE [dbo].[mmsPackage_Adjustments] (
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

SELECT C.Clubname, PKG.Packageid, VPAT.Description AS AdjustmentDescription, P.Description AS ProductDescription, 
PKGA.Sessionsadjusted, P.Productid, C.ClubID, VPAT.Valpackageadjustmenttypeid, 
M.Memberid, M.Firstname AS MemberFirstname, M.Lastname AS MemberLastname, PKGA.Comment,R.Description AS Region,
PKGA.Adjusteddatetime as Adjusteddatetime_Sort,
Replace(Substring(convert(varchar,PKGA.Adjusteddatetime,100),1,6)+', '+Substring(convert(varchar,PKGA.Adjusteddatetime,100),8,10)+' '+Substring(convert(varchar,PKGA.Adjusteddatetime,100),18,2),'  ',' ') as Adjusteddatetime,
CASE WHEN P.Description LIKE '%30 minute%' 
     THEN 1 
     ELSE 0 END AS Half_Session_Flag, 
     
M.MembershipID,		-- added 11/17/2009 GRB
CASE WHEN @PartnerProgramList = '< Do Not Limit By Partner Program >' --2/28/2011 BSD 
          THEN 'Not limited by Partner Program' --2/28/2011 BSD 
     ELSE PPM.PartnerProgramList  --2/28/2011 BSD 
END AS SelectedPartnerPrograms, --2/28/2011 BSD 
/******  Foreign Currency Stuff  *********/
	   VCC.CurrencyCode as LocalCurrencyCode,
       #PlanRate.PlanRate,
       @ReportingCurrencyCode as ReportingCurrencyCode,
	   PKGA.Amountadjusted * #PlanRate.PlanRate as Amountadjusted,	   
	   PKGA.Amountadjusted as LocalCurrency_Amountadjusted,	 
	   PKGA.Amountadjusted * #ToUSDPlanRate.PlanRate as USD_Amountadjusted  	   	
/***************************************/

FROM dbo.vPackageAdjustment PKGA
  JOIN dbo.vValPackageAdjustmentType VPAT
    ON PKGA.Valpackageadjustmenttypeid = VPAT.Valpackageadjustmenttypeid
  JOIN dbo.vPackage PKG
    ON PKGA.Packageid = PKG.Packageid
  JOIN dbo.vMember M
    ON PKG.Memberid = M.Memberid
  JOIN dbo.vProduct P
    ON PKG.Productid = P.Productid
  JOIN #DepartmentIDs
    ON P.DepartmentID = #DepartmentIDs.DepartmentID
  JOIN dbo.vClub C
    ON PKG.Clubid = C.Clubid
/********** Foreign Currency Stuff **********/
  JOIN vValCurrencyCode VCC
       ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID
  JOIN #PlanRate
       ON VCC.CurrencyCode = #PlanRate.FromCurrencyCode
      AND YEAR(PKGA.Adjusteddatetime) = #PlanRate.PlanYear
  JOIN #ToUSDPlanRate
       ON VCC.CurrencyCode = #ToUSDPlanRate.FromCurrencyCode
      AND YEAR(PKGA.Adjusteddatetime) = #ToUSDPlanRate.PlanYear
/*******************************************/
JOIN #Clubs tC
    ON C.Clubid = tC.ClubID
  JOIN dbo.vValRegion R
    ON C.Valregionid = R.Valregionid
LEFT JOIN #PartnerProgramMembers PPM --2/28/2011 BSD
    ON M.MemberID = PPM.MemberID --2/28/2011 BSD
WHERE PKGA.Valpackageadjustmenttypeid != 2   -----  is not a void 
  AND PKGA.Adjusteddatetime >= @StartDate  
  AND PKGA.Adjusteddatetime <= @EndDate  
  AND ISNULL(PPM.MemberID,'-999') = CASE WHEN @PartnerProgramList = '< Do Not Limit By Partner Program >' --2/28/2011 BSD
                                               THEN ISNULL(PPM.MemberID,'-999') --2/28/2011 BSD
                                          ELSE M.MemberID END --2/28/2011 BSD



DROP TABLE #Clubs
DROP TABLE #TmpList
DROP TABLE #PartnerPrograms
DROP TABLE #DepartmentIDs
DROP TABLE #PlanRate
DROP TABLE #ToUSDPlanRate

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END

