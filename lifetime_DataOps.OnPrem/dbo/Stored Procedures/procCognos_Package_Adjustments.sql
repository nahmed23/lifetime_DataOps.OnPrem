


------------------------------------------------------------------------------------------------------------------------
/*	=============================================
Object:			dbo.procCognos_Package_Adjustments
Description:	Returns listing of Package Product session adjustments within a selected date range
Exec procCognos_Package_Adjustments '0', 'Jan 5, 2011', 'Apr 5, 2012', 'All', 'All','Not Limited by myLT Buck$', '0'
	=============================================	*/

CREATE PROCEDURE [dbo].[procCognos_Package_Adjustments] (
       @ClubIDs VARCHAR(1000),
       @StartDate DATETIME,
       @EndDate DATETIME,
       @PartnerProgramList VARCHAR(2000), 
       @MMSDeptIDList VARCHAR(1000),
       @myLTBucksFilter VARCHAR(100), 
	   @CurrencyCode AS VARCHAR(3)      
) 
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

DECLARE @HeaderDateRange VARCHAR(33), @ReportRunDateTime VARCHAR(21) 
SET @HeaderDateRange = convert(varchar(12), @StartDate, 107) + ' to ' + convert(varchar(12), @EndDate, 107)
SET @ReportRunDateTime = Replace(Substring(convert(varchar,getdate(),100),1,6)+', '+Substring(convert(varchar,GETDATE(),100),8,10)+' '+Substring(convert(varchar,getdate(),100),18,2),'  ',' ')


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
SET @ReportingCurrencyCode = CASE WHEN @CurrencyCode <> '0' THEN @CurrencyCode ELSE @ReportingCurrencyCode END

CREATE TABLE #PlanRate (PlanRate DECIMAL(14,4), FromCurrencyCode VARCHAR(15), PlanYear INT)
INSERT INTO #PlanRate
SELECT PlanExchangeRate, FromCurrencyCode, PlanYear
FROM PlanExchangeRate
WHERE ToCurrencyCode = @ReportingCurrencyCode

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

DECLARE @HeaderDepartmentList AS VARCHAR(2000)
SET @HeaderDepartmentList = STUFF((SELECT DISTINCT ', ' + D.Description 
                                       FROM #DepartmentIDS tD
                                       JOIN vDepartment D ON D.DepartmentID = tD.DepartmentID                                       
                                       FOR XML PATH('')),1,1,'')   

DECLARE @HeaderPartnerProgramList AS VARCHAR(2000)
SET @HeaderPartnerProgramList = STUFF((SELECT DISTINCT ', ' + RP.ReimbursementProgramName 
                                       FROM #PartnerPrograms tPP
                                       JOIN vReimbursementProgram RP ON RP.ReimbursementProgramName = tPP.PartnerProgram OR tPP.PartnerProgram = 'All'                                      
                                       FOR XML PATH('')),1,1,'')   
SET @HeaderPartnerProgramList = CASE WHEN @PartnerProgramList = 'All' THEN 'Not Limited By Partner Program' 
                                     WHEN @PartnerProgramList like '%< All Partner Program Members >%' THEN 'All Partner Programs'
                                     ELSE @HeaderPartnerProgramList END
                                     
SET @EndDate = DATEADD(DAY,1,@EndDate)

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
  OR @PartnerProgramList like '%< All Partner Program Members >%'
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

SELECT 
R.Description AS Region,
C.ClubID, 
C.Clubname, 
P.Description AS ProductDescription,
VPAT.Description AS AdjustmentDescription, 
@ReportingCurrencyCode as ReportingCurrencyCode,
PKGA.Amountadjusted * #PlanRate.PlanRate as Amountadjusted,	
Replace(Substring(convert(varchar,PKGA.Adjusteddatetime,100),1,6)+', '+Substring(convert(varchar,PKGA.Adjusteddatetime,100),8,10)+' '+Substring(convert(varchar,PKGA.Adjusteddatetime,100),18,2),'  ',' ') as Adjusteddatetime,
CASE WHEN P.Description LIKE '%30 minute%' 
     THEN PKGA.Sessionsadjusted / 2.0 
     ELSE PKGA.Sessionsadjusted END AS SessionsAdjusted, 
PKGA.Adjusteddatetime as Adjusteddatetime_Sort,
M.Memberid, M.Firstname AS MemberFirstname, M.Lastname AS MemberLastname, 
PPM.PartnerProgramList AS PartnerProgramList,
@HeaderDateRange AS HeaderDateRange,
@HeaderDepartmentList AS HeaderDepartmentList,
@HeaderPartnerProgramList AS HeaderPartnerProgramList,
@ReportRunDateTime AS ReportRunDateTime,
@myLTBucksFilter as HeaderMyLTBucks


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
/*******************************************/
JOIN #Clubs tC
    ON C.Clubid = tC.ClubID
  JOIN dbo.vValRegion R
    ON C.Valregionid = R.Valregionid
LEFT JOIN #PartnerProgramMembers PPM 
    ON M.MemberID = PPM.MemberID
WHERE PKGA.Valpackageadjustmenttypeid != 2   -----  is not a void 
  AND PKGA.Adjusteddatetime >= @StartDate  
  AND PKGA.Adjusteddatetime < @EndDate  
  AND ISNULL(PPM.MemberID,'-999') = 
      CASE WHEN @PartnerProgramList = 'All' 
           THEN ISNULL(PPM.MemberID,'-999')
           ELSE M.MemberID END 
  AND (
       (PKG.EmployeeID = -5 and @myLTBucksFilter = 'myLT Buck$ Only')
        OR
       (PKG.EmployeeID is Null and @myLTBucksFilter ='Exclude myLT Buck$')
        OR
       (PKG.EmployeeID <> -5 and @myLTBucksFilter ='Exclude myLT Buck$')
        OR
       (@myLTBucksFilter = 'Not Limited by myLT Buck$'))

DROP TABLE #Clubs
DROP TABLE #TmpList
DROP TABLE #PartnerPrograms
DROP TABLE #DepartmentIDs
DROP TABLE #PlanRate

END


