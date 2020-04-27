


--PackageSessionsDetail
CREATE PROC [dbo].[procCognos_Package_SessionsDetail](
       @ClubIDs VARCHAR(1000),
       @StartDate DATETIME,
       @EndDate DATETIME,
       @MMSDeptIDList VARCHAR(1000),
       @PartnerProgramList VARCHAR(2000),
       @myLTBucksFilter VARCHAR(100),       
	   @CurrencyCode AS VARCHAR(3)
) 
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

/*	=============================================
Description:	This query returns delivered sessions within a selected date range.
Modified date:	1/28/2013 BSD: changed ProductGroup to ReportDimProduct and ReportDimReportingHierarchy QC#2087

exec mmsPackage_SessionsDetail '8|131|140','Nov 1, 2010','Nov 30, 2010','10','All'
EXEC proccognos_Package_SessionsDetail '205', 'Apr 5, 2012', 'Apr 5, 2012', 'All', 'All','Exclude myLT Buck$','usd' 
select * from vclub where clubname like 'wood%'
	=============================================	*/

/*
Section qSessionsDelivered ---- RR Member Connectivity Section 2), 3) 4) and new 4.5) ( FitPoint – First 30 Days) 
	1) DBCR required – Update the stored procedure “mmsPackage_SessionsDetail” 
		a) Join in view vMembership to return vMembership.CreatedDateTime.
		b) Return new data item “MembershipAgeInDaysAtDelivery” finding the number of days from the Membership.CreatedDateTime to the Session.DeliveredDateTime
		c) Change the case logic for the column “Half_Session_Flag” to flag any product with the text ’30 minute’ in the product description instead of using hard coded product IDs.  ---- RR Average Session Price 2)
		d) Return new data item MMST.EmployeeID as TransactionEmployeeID at the end of the Select statement.
		e) Left Join in view vProductGroup on vProductGroup.ProductID = vProduct.ProductID
		f) Left Join in view vValProductGroup on vProductGroup.ValProductGroupID = vValProductGroup.ValProductGroupID
		g) Return new data items vValProductGroup.ValProductGroupID and vValProductGroup.Description as ProgramProductGroupDescription
*/

DECLARE @HeaderDateRange VARCHAR(33), @ReportRunDateTime VARCHAR(21) 
SET @HeaderDateRange = convert(varchar(12), @StartDate, 107) + ' to ' + convert(varchar(12), @EndDate, 107)
SET @ReportRunDateTime = Replace(Substring(convert(varchar,getdate(),100),1,6)+', '+Substring(convert(varchar,GETDATE(),100),8,10)+' '+Substring(convert(varchar,getdate(),100),18,2),'  ',' ')


CREATE TABLE #tmpList(StringField VARCHAR(50))

CREATE TABLE #Clubs(ClubID VARCHAR(50))
IF @ClubIDs <> 'All'
BEGIN
	---- Parse the ClubIDs into a temp table
	EXEC procParseStringList @ClubIDs	
	INSERT INTO #Clubs(ClubID) SELECT StringField FROM #tmpList
END
ELSE
BEGIN
   INSERT INTO #Clubs VALUES('0') -- all clubs
END  


/********  Foreign Currency Stuff ********/
DECLARE @ReportingCurrencyCode VARCHAR(15)
SET @ReportingCurrencyCode = 
(SELECT CASE WHEN COUNT(DISTINCT C.ValCurrencyCodeID) >=2 THEN 'USD' ELSE MAX(VCC.CurrencyCode) END AS ReportingCurrency
  FROM vClub C
  JOIN #Clubs ON C.ClubID = #Clubs.ClubID OR #Clubs.ClubID = 0
  JOIN vValCurrencyCode VCC ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID)
SET @ReportingCurrencyCode = CASE WHEN @CurrencyCode <> '0' THEN @CurrencyCode ELSE @ReportingCurrencyCode END

CREATE TABLE #PlanRate (PlanRate DECIMAL(14,4), FromCurrencyCode VARCHAR(15), PlanYear INT)
INSERT INTO #PlanRate
SELECT PlanExchangeRate, FromCurrencyCode, PlanYear
FROM PlanExchangeRate
WHERE ToCurrencyCode = @ReportingCurrencyCode

/***************************************/



TRUNCATE TABLE #tmpList
CREATE TABLE #DepartmentIDs (DepartmentID VARCHAR(50))
IF @MMSDeptIDList = 'All'
 BEGIN
  INSERT INTO #DepartmentIDS (DepartmentID) SELECT DepartmentID FROM vDepartment
 END
ELSE
 BEGIN
  EXEC procParseStringList @MMSDeptIDList
  INSERT INTO #DepartmentIDs SELECT StringField FROM #tmpList
 END


TRUNCATE TABLE #tmpList
CREATE TABLE #PartnerPrograms (PartnerProgram Varchar(50))
EXEC procParseStringList @PartnerProgramList
INSERT INTO #PartnerPrograms (PartnerProgram) SELECT StringField FROM #tmpList



DECLARE @HeaderDepartmentList AS VARCHAR(2000)
SET @HeaderDepartmentList = STUFF((SELECT DISTINCT ', ' + D.Description 
                                       FROM #DepartmentIDS tD
                                       JOIN vDepartment D ON D.DepartmentID = tD.DepartmentID                                       
                                       FOR XML PATH('')),1,1,'')   

DECLARE @HeaderPartnerProgramList AS VARCHAR(2000)
SET @HeaderPartnerProgramList = STUFF((SELECT DISTINCT ', ' + RP.ReimbursementProgramName 
                                       FROM #PartnerPrograms tPP
                                       JOIN vReimbursementProgram RP ON RP.ReimbursementProgramName = tPP.PartnerProgram                                       
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
WHERE MR.EnrollmentDate < @EndDate
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


------  Return result set

SELECT 
       R.Description AS RegionDescription,
       RC.Clubname AS RevenueClub, 
       RC.Clubid AS RevenueClubID, 
       CASE WHEN P.Description LIKE '%30 minute%' THEN 0.5 ELSE 1 END AS SessionCount, 
       S.Sessionprice * #PlanRate.PlanRate as Sessionprice,
       -- COUNT EMPLOYEE FOR DELIVERED CLUB ; ONE EMPLOYEE CAN WORK IN MORE THAN ONE CLUB
       E.EmployeeID as DeliveredEmployeeID,
       E.FirstName as DeliveredEmployeeFirstName,
       E.LastName as DeliveredEmployeeLastName,
       M.Memberid, 
       M.Firstname AS MemberFirstname, 
       M.Lastname AS MemberLastname,  
       S.Delivereddatetime as Deliverddatetime_Sort,
	   Replace(Substring(convert(varchar,S.Delivereddatetime,100),1,6)+', '+Substring(convert(varchar,S.Delivereddatetime,100),8,10)+' '+Substring(convert(varchar,S.Delivereddatetime,100),18,2),'  ',' ') as Delivereddatetime,
  	   P.Productid, 
       P.Description AS ProductDescription,
       SC.Clubname AS SaleClub,        
       CASE WHEN VPS.description = 'Voided' THEN '*' ELSE '' END  VoidedPackageFlag, 
       PPM.PartnerProgramList,
       @HeaderDateRange AS HeaderDateRange,
       @HeaderDepartmentList AS HeaderDepartmentList,
       @HeaderPartnerProgramList AS HeaderPartnerProgramList,
       @ReportRunDateTime AS ReportRunDateTime,
       @ReportingCurrencyCode as ReportingCurrencyCode,
       @myLTBucksFilter as HeaderMyLTBucks      
    
  FROM dbo.vPackagesession S
  JOIN dbo.vClub RC
    ON S.Clubid = RC.Clubid
  JOIN vValCurrencyCode VCC
       ON RC.ValCurrencyCodeID = VCC.ValCurrencyCodeID
  JOIN #PlanRate
       ON VCC.CurrencyCode = #PlanRate.FromCurrencyCode
      AND YEAR(S.Delivereddatetime) = #PlanRate.PlanYear
  JOIN #Clubs tC
    ON (RC.Clubid = tC.ClubID OR tC.ClubID = 0)
  JOIN dbo.vValRegion R
    ON RC.Valregionid = R.ValRegionID
  JOIN dbo.vEmployee E
    ON S.Deliveredemployeeid = E.Employeeid
  JOIN dbo.vPackage PKG
    ON S.Packageid = PKG.Packageid
  JOIN dbo.vMember M
    ON PKG.Memberid = M.Memberid
  JOIN dbo.vProduct P
    ON PKG.Productid = P.Productid
  JOIN dbo.vValpackagestatus VPS
    ON PKG.Valpackagestatusid = VPS.Valpackagestatusid  
  JOIN dbo.vClub SC
    ON PKG.Clubid = SC.Clubid 
  JOIN vDepartment D 
	 ON D.DepartmentID = P.DepartmentID 
  JOIN #DepartmentIDs  
     ON D.DepartmentID = #DepartmentIDs.DepartmentID 
  LEFT JOIN #PartnerProgramMembers PPM 
     ON M.MemberID = PPM.MemberID
 WHERE S.Delivereddatetime >= @StartDate 
   AND S.Delivereddatetime < @EndDate    
   AND ISNULL(PPM.MemberID,'-999') = CASE WHEN @PartnerProgramList = 'All' 
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
DROP TABLE #DepartmentIDs 
DROP TABLE #PartnerPrograms
DROP TABLE #PartnerProgramMembers
DROP TABLE #PlanRate


END



