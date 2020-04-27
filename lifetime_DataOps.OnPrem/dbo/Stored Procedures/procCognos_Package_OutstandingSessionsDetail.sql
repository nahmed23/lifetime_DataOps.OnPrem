


CREATE PROC [dbo].[procCognos_Package_OutstandingSessionsDetail](
     @ClubIDList VARCHAR(1000),
     @MMSDeptIDList VARCHAR(1000),
     @PartnerProgramList  VARCHAR(8000), 
     @myLTBucksFilter VARCHAR(100),     
	 @CurrencyCode VARCHAR(3)
) 
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

/*	=============================================
Description:	This query returns outstanding sessions as of the report run date.
Modified date:	
exec procCognos_Package_OutstandingSessionsDetail '151','9','All','Not Limited by myLT Buck$','0'
	=============================================	*/



  CREATE TABLE #tmpList (StringField VARCHAR(50))
  CREATE TABLE #Clubs (MMSClubID INT)

 
  INSERT INTO #Clubs (MMSClubID) 
  SELECT DISTINCT Club.ClubID
  FROM vClub Club
  JOIN fnParsePipeList(@ClubIDList) ClubIDList
    ON ClubIDList.Item = Convert(Varchar,Club.ClubID) 
      OR ClubIDList.Item = '0'

  TRUNCATE TABLE #tmpList

/********  Foreign Currency Stuff ********/
DECLARE @ReportingCurrencyCode VARCHAR(15)
SET @ReportingCurrencyCode = 
(SELECT CASE WHEN COUNT(DISTINCT C.ValCurrencyCodeID) >=2 THEN 'USD' ELSE MAX(VCC.CurrencyCode) END AS ReportingCurrency
  FROM vClub C
  JOIN #Clubs ON C.ClubID = #Clubs.MMSClubID
  JOIN vValCurrencyCode VCC ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID)
  
SET @ReportingCurrencyCode = CASE WHEN @CurrencyCode <> '0' THEN @CurrencyCode ELSE @ReportingCurrencyCode END

CREATE TABLE #PlanRate (PlanRate DECIMAL(14,4), FromCurrencyCode VARCHAR(15), PlanYear INT)
INSERT INTO #PlanRate
SELECT PlanExchangeRate, FromCurrencyCode, PlanYear
FROM PlanExchangeRate
WHERE ToCurrencyCode = @ReportingCurrencyCode


/***************************************/

TRUNCATE TABLE #tmpList
CREATE TABLE #DepartmentIDs (DepartmentID INT)
IF @MMSDeptIDList = 'All Departments'
 BEGIN
  INSERT INTO #DepartmentIDs (DepartmentID) SELECT DepartmentID FROM vDepartment
 END
ELSE
 BEGIN
  INSERT INTO #DepartmentIDs (DepartmentID) 
     SELECT DISTINCT Department.DepartmentID 
       FROM vDepartment Department 
       JOIN fnParsePipeList(@MMSDeptIDList) DeptIDList
         ON DeptIDList.Item = Convert(Varchar,Department.DepartmentID)
 END


DECLARE @ReportRunDateTime VARCHAR(21) 
SET @ReportRunDateTime = Replace(Substring(convert(varchar,getdate(),100),1,6)+', '+Substring(convert(varchar,GETDATE(),100),8,10)+' '+Substring(convert(varchar,getdate(),100),18,2),'  ',' ')



DECLARE @HeaderDepartmentList AS VARCHAR(2000)
SET @HeaderDepartmentList = STUFF((SELECT DISTINCT ', ' + D.Description 
                                       FROM #DepartmentIDS tD
                                       JOIN vDepartment D ON D.DepartmentID = tD.DepartmentID                                       
                                       FOR XML PATH('')),1,1,'')   


TRUNCATE TABLE #tmpList
CREATE TABLE #PartnerPrograms (PartnerProgram Varchar(50))
EXEC procParseStringList @PartnerProgramList
INSERT INTO #PartnerPrograms (PartnerProgram) SELECT StringField FROM #tmpList                                       
                                       

DECLARE @HeaderPartnerProgramList AS VARCHAR(2000)
SET @HeaderPartnerProgramList = STUFF((SELECT DISTINCT ', ' + RP.ReimbursementProgramName 
                                       FROM #PartnerPrograms tPP
                                       JOIN vReimbursementProgram RP ON RP.ReimbursementProgramName = tPP.PartnerProgram                                       
                                       FOR XML PATH('')),1,1,'')   
SET @HeaderPartnerProgramList = CASE WHEN @PartnerProgramList = 'All' THEN 'Not Limited By Partner Program' 
                                     WHEN @PartnerProgramList like '%< All Partner Program Members >%' THEN 'All Partner Programs'
                                     ELSE @HeaderPartnerProgramList END

DECLARE @EndDate DateTime
SET @EndDate = DATEADD(DAY,1,GETDATE())



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
WHERE MR.EnrollmentDate < @EndDate
  AND (MR.TerminationDate >= @EndDate OR MR.TerminationDate IS NULL)
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




SELECT R.Description AS SalesRegionDescription,
       C.ClubName AS SalesClubname, 
       E.EmployeeID, 
       E.FirstName AS TeamMemberFirstname, 
       E.LastName AS TeamMemberLastname, 
       Replace(Substring(convert(varchar,PKG.CreatedDateTime,100),1,6)+', '+Substring(convert(varchar,PKG.CreatedDateTime,100),8,10)+' '+Substring(convert(varchar,PKG.CreatedDateTime,100),18,2),'  ',' ') as PackageCreatedDateTime,   
       M.MemberID, 
       M.FirstName AS MemberFirstname, 
       M.LastName AS MemberLastname, 
       P.Description AS ProductDescription,
       PKG.Packageid, 
       P.Productid,
       VPS.Description AS PackageStatusDescription,
       VDS.Description AS DrawerStatusDescription, 
       MSC.ClubName AS MembershipHomeClub,
       EC.ClubName AS TeamMemberHomeClub, 
       CASE WHEN P.Description LIKE '%30 minute%' 
            THEN cast(PKG.NumberOfSessions * 0.5 as decimal(4,1)) 
            ELSE cast(PKG.NumberOfSessions as decimal(4,1)) 
            END OriginalNumberOfSessions, 
       CASE WHEN P.Description LIKE '%30 minute%' 
            THEN cast(PKG.SessionsLeft * 0.5 as decimal(4,1))
            ELSE cast(PKG.SessionsLeft as decimal(4,1))
            END SessionsLeft, 
       D.Description AS MMSDepartment,
       PPM.PartnerProgramList,
       #PlanRate.PlanRate,
       @ReportingCurrencyCode as ReportingCurrencyCode,
	   PKG.BalanceAmount * #PlanRate.PlanRate as BalanceAmount,
	   @ReportRunDateTime as ReportRunDateTime,
	   @HeaderDepartmentList as HeaderDepartmentList,
	   @HeaderPartnerProgramList as HeaderPartnerProgramList,
	   @myLTBucksFilter as HeaderMyLTBucks,
	   C.ClubID As SalesClubID
	   	   	
/***************************************/

FROM dbo.vPackage PKG
  JOIN dbo.vCLUB C
     ON C.ClubID=PKG.ClubID
JOIN #Clubs tC
    ON C.Clubid = tC.MMSClubID
/********** Foreign Currency Stuff **********/
  JOIN vValCurrencyCode VCC
       ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID
  JOIN #PlanRate
       ON VCC.CurrencyCode = #PlanRate.FromCurrencyCode
      AND YEAR(GETDATE()) = #PlanRate.PlanYear

/*******************************************/
  JOIN dbo.vValRegion R
     ON C.ValRegionID = R.ValRegionID
  JOIN dbo.vMember M
     ON M.MemberID=PKG.MemberID
  JOIN dbo.vMembership MS
     ON M.MembershipID = MS.MembershipID
  JOIN dbo.vCLUB MSC
     ON MS.ClubID = MSC.ClubID
  LEFT JOIN dbo.vEmployee E
     ON PKG.EmployeeID=E.EmployeeID
  LEFT JOIN dbo.vCLUB EC
     ON E.ClubID = EC.ClubID
  JOIN dbo.vProduct P
     ON PKG.ProductID=P.ProductID
  JOIN dbo.vValPackageStatus VPS
     ON PKG.ValPackageStatusID = VPS.ValPackageStatusID
  JOIN dbo.vMMSTran MT
     ON PKG.MMSTranID = MT.MMSTranID
  JOIN dbo.vDrawerActivity DA
     ON MT.DrawerActivityID = DA.DrawerActivityID
  JOIN dbo.vValDrawerStatus VDS
     ON DA.ValDrawerStatusID = VDS.ValDrawerStatusID
  JOIN dbo.vDepartment D 
	 ON D.DepartmentID = P.DepartmentID 
  JOIN #DepartmentIDs
     ON D.DepartmentID = #DepartmentIDs.DepartmentID
  LEFT JOIN #PartnerProgramMembers PPM
     ON M.MemberID = PPM.MemberID
WHERE  VPS.Description Not IN('Completed','Voided')
  AND ISNULL(PPM.MemberID,-999) = CASE WHEN @PartnerProgramList = 'All' 
                                               THEN ISNULL(PPM.MemberID,-999)
                                          ELSE M.MemberID END 
  AND (
       (PKG.EmployeeID = -5 and @myLTBucksFilter = 'myLT Buck$ Only')
        OR
       (PKG.EmployeeID is Null and @myLTBucksFilter ='Exclude myLT Buck$')
        OR
       (PKG.EmployeeID <> -5 and @myLTBucksFilter ='Exclude myLT Buck$')
        OR
       (@myLTBucksFilter = 'Not Limited by myLT Buck$'))
ORDER BY R.Description,C.ClubName,E.FirstName,E.LastName,P.Description
       

DROP TABLE #Clubs
DROP TABLE #tmpList
DROP TABLE #DepartmentIDs
DROP TABLE #PlanRate
DROP TABLE #PartnerProgramMembers
DROP TABLE #PartnerPrograms

END


