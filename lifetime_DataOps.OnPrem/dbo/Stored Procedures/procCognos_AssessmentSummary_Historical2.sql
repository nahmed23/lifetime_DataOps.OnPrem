




CREATE PROCEDURE [dbo].[procCognos_AssessmentSummary_Historical2] (
  @ClubIDList VARCHAR(2000),
  @InputStartDate DATETIME,
  @InputEndDate DATETIME,
  @DepartmentIDList VARCHAR(2000)
)

AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON


IF 1=0 BEGIN
       SET FMTONLY OFF
     END



---  Sample Execution
---   EXEC procCognos_AssessmentSummary_Historical2 '151', '8/1/2019', '8/1/2019', '1|20|21|22|23'
---



  CREATE TABLE #tmpList (StringField VARCHAR(50))
  CREATE TABLE #Clubs (ClubID VARCHAR(50))
IF @ClubIDList <> 'All'
BEGIN
   EXEC procParseStringList @ClubIDList
   INSERT INTO #Clubs (ClubID) SELECT StringField FROM #tmpList
   TRUNCATE TABLE #tmpList
END
ELSE
BEGIN
   INSERT INTO #Clubs (ClubID) SELECT ClubID FROM vClub WHERE DisplayUIFlag = 1
END   

CREATE TABLE #Departments (DepartmentID INT)
IF @DepartmentIDList <> 'All'
BEGIN
   EXEC procParseStringList @DepartmentIDList
   INSERT INTO #Departments (DepartmentID) SELECT StringField FROM #tmpList
   TRUNCATE TABLE #tmpList
END
ELSE
BEGIN
   INSERT INTO #Departments (DepartmentID) SELECT DepartmentID FROM vDepartment 
END   


DECLARE @HeaderMMSDepartmentsList AS VARCHAR(2000)
SET @HeaderMMSDepartmentsList = STUFF((SELECT ', ' + D.Description 
                                       FROM vDepartment D
                                       JOIN #Departments tD ON D.DepartmentID = tD.DepartmentID
                                       FOR XML PATH('')),1,1,'')   

/********  Foreign Currency Stuff ********/
DECLARE @ReportingCurrencyCode VARCHAR(15)
SET @ReportingCurrencyCode = 
(SELECT CASE WHEN COUNT(DISTINCT C.ValCurrencyCodeID) >=2 THEN 'USD' ELSE MAX(VCC.CurrencyCode) END AS ReportingCurrency
  FROM vClub C
  JOIN #Clubs ON C.ClubID = #Clubs.ClubID OR #Clubs.ClubID = 0
  JOIN vValCurrencyCode VCC ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID)

CREATE TABLE #PlanRate (PlanRate DECIMAL(14,4), FromCurrencyCode VARCHAR(15), PlanYear INT)
INSERT INTO #PlanRate
SELECT PlanExchangeRate, FromCurrencyCode, PlanYear
FROM PlanExchangeRate
WHERE PlanYear >= Year(@InputStartDate)
  AND PlanYear <= Year(@InputEndDate)
  AND ToCurrencyCode = @ReportingCurrencyCode


DECLARE @HeaderAssessmentDateRange VARCHAR(33), @ReportRunDateTime VARCHAR(21) 
SET @HeaderAssessmentDateRange = convert(varchar(12), @InputStartDate, 107) + ' through ' + convert(varchar(12), @InputEndDate, 107)
SET @ReportRunDateTime = Replace(Substring(convert(varchar,getdate(),100),1,6)+', '+Substring(convert(varchar,GETDATE(),100),8,10)+' '+Substring(convert(varchar,getdate(),100),18,2),'  ',' ')

SET @InputEndDate = DATEADD(DAY,1,@InputEndDate)

SELECT DISTINCT 
       MMST.MMSTranID, 
       MMST.ClubID,
       MMST.MembershipID, 
       MMST.MemberID, 
       MMST.ReasonCodeID, 
       MMST.ValTranTypeID, 
       MMST.PostDateTime, 
       MMST.EmployeeID, 
       TI.TranItemID,          
	   TI.ItemAmount,
	   TI.ItemSalesTax,
	   TI.Quantity

INTO #MMSTran
FROM vMMSTran MMST
JOIN #Clubs
  ON MMST.ClubID = #Clubs.ClubID
JOIN vTranItem TI
  ON MMST.MMSTranID = TI.MMSTranID

WHERE MMST.PostDateTime > @InputStartDate
  AND MMST.PostDateTime < @InputEndDate
  AND MMST.ValTranTypeID = 1
  AND MMST.EmployeeID = -2
  AND ReasonCodeID in(125,28,114)     ------- Added because transactions for other reasons were getting into Total Membership Count


/***************************************/

 SELECT 
 VR.Description RegionDescription,
 C.ClubName, 
 MS.MembershipID,
 P.Description as ProductDescription,
 CASE WHEN MT.ReasonCodeID = 125 THEN P2.Description ELSE P.Description END ReportProductGroup,
 CASE WHEN MT.ReasonCodeID = 28 THEN  MS.MembershipID ELSE 0 END AS MonthlyMemberCount,
 CASE WHEN MT.ReasonCodeID = 28 THEN ((MT.ItemAmount) * #PlanRate.PlanRate )ELSE 0 END AS MonthlyMemberDues,
 CASE WHEN MT.ReasonCodeID = 125 THEN MT.Quantity ELSE 0 END AS MonthlyJuniorCount,
 CASE WHEN MT.ReasonCodeID = 125 THEN ((MT.ItemAmount) * #PlanRate.PlanRate )ELSE 0 END AS MonthlyJuniorDues,
 CASE WHEN MT.ReasonCodeID = 114 THEN MS.MembershipID ELSE 0 END AS RecurrentMemberCount,
 CASE WHEN MT.ReasonCodeID = 114 THEN ((MT.ItemAmount) * #PlanRate.PlanRate )ELSE 0 END AS RecurrentMemberDues,
 --1 AS TotalMemberCount,
 NULL AS TotalMemberCount,
 CASE WHEN MT.ReasonCodeID in(125,28,114) THEN (MT.ItemAmount * #PlanRate.PlanRate) ELSE 0 END TotalMembershipDues,
 CASE WHEN MT.ReasonCodeID = 28 THEN ((MT.ItemSalesTax) * #PlanRate.PlanRate )ELSE 0 END AS MonthlyMembershipDuesTax,
 CASE WHEN MT.ReasonCodeID = 125 THEN ((MT.ItemSalesTax) * #PlanRate.PlanRate )ELSE 0 END AS MonthlyJuniorDuesTax,
 CASE WHEN MT.ReasonCodeID = 114 THEN ((MT.ItemSalesTax) * #PlanRate.PlanRate )ELSE 0 END AS RecurrentProductTax,
 CASE WHEN MT.ReasonCodeID in(125,28,114) THEN (MT.ItemSalesTax * #PlanRate.PlanRate) ELSE 0 END TotalAssessmentTax

    INTO #Results    
    FROM #MMSTran MT
         JOIN vMember M ON MT.MemberID = M.MemberID
         JOIN vTranItem TI ON MT.TranItemID = TI.TranItemID
         JOIN vProduct P ON TI.ProductID = P.ProductID
         JOIN vMembership MS ON MT.MembershipID = MS.MembershipID
         JOIN vMembershipType MST ON MS.MembershipTypeID = MST.MembershipTypeID         
         JOIN vProduct P2 ON MST.ProductID = P2.ProductID         
         JOIN vReasonCode RC ON MT.ReasonCodeID = RC.ReasonCodeID
         JOIN vClub C ON MT.ClubID = C.ClubID
         JOIN #Clubs CI ON C.ClubID = CI.ClubID --OR CI.ClubID = 0
         JOIN vValRegion VR ON C.ValRegionID =  VR.ValRegionID
/********** Foreign Currency Stuff **********/
  JOIN vValCurrencyCode VCC
       ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID
  JOIN #PlanRate
       ON VCC.CurrencyCode = #PlanRate.FromCurrencyCode
      AND YEAR(MT.PostDateTime) = #PlanRate.PlanYear
/*******************************************/
  JOIN #Departments
       ON P.DepartmentID = #Departments.DepartmentID
/*******************************************/


  SELECT 
     RegionDescription,
     ClubName, 
     --ReportProductGroup,
	 Count(Distinct MonthlyMemberCount) AS MonthlyMemberCount,
	 SUM(MonthlyMemberDues) AS MonthlyMemberDues,
	 SUM(MonthlyJuniorCount) AS MonthlyJuniorCount,
	 SUM(MonthlyJuniorDues) AS MonthlyJuniorDues,
	 --SUM(RecurrentMemberCount) AS RecurrentMemberCount,
	 Count(Distinct RecurrentMemberCount) AS RecurrentMemberCount,
	 SUM(RecurrentMemberDues) AS RecurrentMemberDues,
	 Count(Distinct MembershipID) AS TotalMemberCount,
	 SUM(TotalMembershipDues) AS TotalMembershipDues,
	 SUM(MonthlyMembershipDuesTax) AS MonthlyMembershipDuesTax,
	 SUM(MonthlyJuniorDuesTax) AS MonthlyJuniorDuesTax,
	 SUM(RecurrentProductTax) AS RecurrentProductTax,
	 SUM(TotalAssessmentTax) AS TotalMembershipDuesTax,
	 @HeaderMMSDepartmentsList AS HeaderMMSDepartmentsList, 
	 @ReportingCurrencyCode as ReportingCurrencyCode,
	 @HeaderAssessmentDateRange AS HeaderAssessmentDate, 
	 @ReportRunDateTime AS ReportRunDateTime
  INTO #PrelimFinal
 FROM #Results
 GROUP BY   RegionDescription,  ClubName
 --,   ReportProductGroup

 Select RegionDescription,
     ClubName,
	 CASE WHEN MonthlyMemberDues = 0 AND (RecurrentMemberCount > 0 or MonthlyJuniorCount >0)
	      THEN MonthlyMemberCount - 1     ----- to remove counting of membership id "0"
		  ELSE MonthlyMemberCount
		  END  MonthlyMemberCount,   
	 MonthlyMemberDues,
	 MonthlyJuniorCount,
	 MonthlyJuniorDues,
	 CASE WHEN RecurrentMemberDues = 0 AND (MonthlyMemberCount > 0 or MonthlyJuniorCount >0)
	      THEN (RecurrentMemberCount - 1)    ----- to remove counting of membership id "0"
		  ELSE RecurrentMemberCount
		  END RecurrentMemberCount,
	 RecurrentMemberDues,
	 TotalMemberCount,
	 TotalMembershipDues,
	 HeaderMMSDepartmentsList, 
	 ReportingCurrencyCode,
	 HeaderAssessmentDate, 
	 ReportRunDateTime,
	 MonthlyMembershipDuesTax,
	 MonthlyJuniorDuesTax,
	 RecurrentProductTax,
	 TotalMembershipDuesTax
FROM #PrelimFinal


  DROP TABLE #Clubs
  DROP TABLE #tmpList
  DROP TABLE #PlanRate
  DROP TABLE #Results
  DROP TABLE #Departments
  DROP TABLE  #MMSTran
  DROP TABLE  #PrelimFinal

END



