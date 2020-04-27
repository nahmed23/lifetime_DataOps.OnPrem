


/*-- =============================================
-- Object:			
-- Description:		Returns all unterminated recurrent products plus any that terminated this month

 
 EXEC procCognos_RecurrentProductForecast
 '2012-07', '2014-08',
 --'West-MN Smith|',
 'West-MN-West',
 --|West-Minnesota|Kevin A-MN|East-Great Lakes|Sean Gladwish|Great Lakes|', 
 '8|', '220', '220|221|222|223|281',  
 '0'
 
 select DimReportingHierarchyKey, DepartmentName,* from vReportDimReportingHierarchy where DepartmentName = 'partner training'
 select * from vclub where clubid = 8
-- =============================================*/

CREATE PROC [dbo].[procCognos_RecurrentProductForecast_Obsolete] (
    @StartFourDigitYearDashTwoDigitMonth VARCHAR(22),
    @EndFourDigitYearDashTwoDigitMonth VARCHAR(22),
	@RegionList VARCHAR(2000),
	@ClubIDList VARCHAR(8000),	
	@DepartmentMinDimReportingHierarchyKeyList VARCHAR(8000), 
	@DimReportingHierarchyKeyList VARCHAR(8000), 	
	@CurrencyCode AS VARCHAR(3))	
AS
BEGIN

SELECT @StartFourDigitYearDashTwoDigitMonth = CASE WHEN @StartFourDigitYearDashTwoDigitMonth = 'Current Month' THEN CurrentMonthDimDate.FourDigitYearDashTwoDigitMonth
                                                   WHEN @StartFourDigitYearDashTwoDigitMonth = 'Next Month' THEN NextMonthDimDate.FourDigitYearDashTwoDigitMonth
                                                   WHEN @StartFourDigitYearDashTwoDigitMonth = 'Month After Next Month' THEN MonthAfterNextMonthDimDate.FourDigitYearDashTwoDigitMonth
                                                   ELSE @StartFourDigitYearDashTwoDigitMonth END,
       @EndFourDigitYearDashTwoDigitMonth = CASE WHEN @EndFourDigitYearDashTwoDigitMonth = 'Current Month' THEN CurrentMonthDimDate.FourDigitYearDashTwoDigitMonth
                                                 WHEN @EndFourDigitYearDashTwoDigitMonth = 'Next Month' THEN NextMonthDimDate.FourDigitYearDashTwoDigitMonth
                                                 WHEN @EndFourDigitYearDashTwoDigitMonth = 'Month After Next Month' THEN MonthAfterNextMonthDimDate.FourDigitYearDashTwoDigitMonth
                                                 ELSE @EndFourDigitYearDashTwoDigitMonth END
  FROM vReportDimDate CurrentMonthDimDate
  JOIN vReportDimDate NextMonthDimDate
    ON CurrentMonthDimDate.NextMonthStartingDimDateKey = NextMonthDimDate.DimDateKey
  JOIN vReportDimDate MonthAfterNextMonthDimDate
    ON NextMonthDimDate.NextMonthStartingDimDateKey = MonthAfterNextMonthDimDate.DimDateKey
 WHERE CurrentMonthDimDate.CalendarDate = CONVERT(DateTime,Convert(Varchar,GetDate()-2,101),101)
 
DECLARE @RecurrentProductStartDate DATETIME, 
         @RecurrentProductEndDate DATETIME
        
SELECT @RecurrentProductStartDate = min(DimDate.CalendarDate)       
FROM vReportDimDate DimDate
WHERE DimDate.FourDigitYearDashTwoDigitMonth = @StartFourDigitYearDashTwoDigitMonth
SELECT @RecurrentProductEndDate = max(DimDate.CalendarMonthEndingDate)
FROM vReportDimDate DimDate
WHERE DimDate.FourDigitYearDashTwoDigitMonth = @EndFourDigitYearDashTwoDigitMonth

 -- start date is adjusted to today's date if it is prior to today's date
SET @RecurrentProductStartDate = CASE WHEN @RecurrentProductStartDate < Convert(Datetime,Convert(Varchar,GetDate(),101),101) 
                                      AND  @RecurrentProductEndDate >= Convert(Datetime,Convert(Varchar,GetDate(),101),101) 
                            THEN Convert(Datetime,Convert(Varchar,GetDate(),101),101)
                            ELSE @RecurrentProductStartDate END

-- assessment dates for every month selected
CREATE TABLE #tmpList (StringField VARCHAR(50))
CREATE TABLE #Dates (YEAR INT, MONTH INT, MonthDescription VARCHAR(9), ValAssessmentDayID INT, AssessmentDay INT, AssessmentDate DATETIME)


DECLARE @CurrentDate DATETIME
SET @CurrentDate = @RecurrentProductStartDate
WHILE @CurrentDate <= @RecurrentProductEndDate 
BEGIN
	INSERT INTO #Dates (YEAR, MONTH, MonthDescription, AssessmentDate, ValAssessmentDayID, AssessmentDay) 
	       SELECT YEAR(@CurrentDate), MONTH(@CurrentDate), DateName( month , DateAdd( month , MONTH(@CurrentDate) , -1 ) ) , CAST(CAST(MONTH(@CurrentDate) AS VARCHAR(2))+'/'+CAST(AssessmentDay AS VARCHAR(2))+'/'+CAST(YEAR(@CurrentDate)AS VARCHAR(4)) AS DATETIME), ValAssessmentDayID, AssessmentDay
	       FROM vValAssessmentDay
	SET @CurrentDate  = DATEADD(M,1,@CurrentDate)
	
END
-- remove dates that are prior to today's date
DELETE FROM #Dates WHERE AssessmentDate NOT BETWEEN @RecurrentProductStartDate AND @RecurrentProductEndDate


DECLARE @StartMonthStartingDimDateKey INT,
        @EndMonthEndingDimDateKey INT        

SELECT @StartMonthStartingDimDateKey  = MIN(MonthStartingDimDateKey),
       @EndMonthEndingDimDateKey = MAX(MonthEndingDimDateKey)
FROM vReportDimDate
WHERE CalendarDate BETWEEN @RecurrentProductStartDate AND @RecurrentProductEndDate

CREATE TABLE #Regions (RegionName VARCHAR(50))
EXEC procParseStringList @RegionList
INSERT INTO #Regions (RegionName) SELECT StringField FROM #tmpList
TRUNCATE TABLE #tmpList

CREATE TABLE #Clubs (ClubID VARCHAR(50))
IF @ClubIDList <> 'All'
 BEGIN -- Parse the ClubIDs into a temp table
  EXEC procParseIntegerList @ClubIDList
  INSERT INTO #Clubs (ClubID) SELECT StringField FROM #tmpList
  TRUNCATE TABLE #tmpList
 END
ELSE
 BEGIN
  INSERT INTO #Clubs (ClubID) SELECT ClubID FROM vClub
 END

-- Departments
SELECT DISTINCT
       DimReportingHierarchyKey,
       DepartmentMinDimReportingHierarchyKey,
       HeaderDivisionList,
       HeaderSubdivisionList,
       HeaderDepartmentList,
       HeaderProductGroupList,
       ReportRegionType
  INTO #Departments
  FROM fnRevenueDimReportingHierarchy('n/a', 'n/a', @DepartmentMinDimReportingHierarchyKeyList,@DimReportingHierarchyKeyList,@StartMonthStartingDimDateKey,@EndMonthEndingDimDateKey)



CREATE TABLE #RegionClub (Clubid INT, ClubName VARCHAR(50), RegionName VARCHAR(50))
INSERT INTO #RegionClub 
SELECT C.Clubid, ClubName, 
CASE WHEN Description IS NULL THEN 'None Designated' ELSE Description END RegionName
FROM vClub C
LEFT JOIN vValRegion MMSR ON MMSR.valregionid = C.valregionid
JOIN #Clubs tC ON tC.ClubID = C.ClubID
JOIN #Regions tR ON tR.RegionName = MMSR.Description OR MMSR.Description IS NULL
UNION 
SELECT C.Clubid, ClubName, 
CASE WHEN Description IS NULL THEN 'None Designated' ELSE Description END RegionName
FROM vClub C
LEFT JOIN vvalptrclarea PTR ON PTR.valptrclareaid = C.ValPTRCLAreaID
JOIN #Clubs tC ON tC.ClubID = C.ClubID
JOIN #Regions tR ON tR.RegionName = PTR.Description OR PTR.Description IS NULL
UNION
SELECT C.Clubid, ClubName, 
CASE WHEN Description IS NULL THEN 'None Designated' ELSE Description END RegionName
FROM vClub C
LEFT JOIN vValMemberActivityRegion MAR ON MAR.ValMemberActivityRegionID = C.ValMemberActivityRegionID
JOIN #Clubs tC ON tC.ClubID = C.ClubID
JOIN #Regions tR ON tR.RegionName = MAR.Description OR MAR.Description IS NULL
ORDER BY ClubID


-- report sub headers
DECLARE @ReportRunDateTime VARCHAR(21) 
SET @ReportRunDateTime = Replace(Substring(convert(varchar,getdate(),100),1,6)+', '+Substring(convert(varchar,GETDATE(),100),8,10)+' '+Substring(convert(varchar,getdate(),100),18,2),'  ',' ')

DECLARE @HeaderDivisionList AS VARCHAR(2000)
SET @HeaderDivisionList = STUFF((SELECT DISTINCT ', ' + HeaderDivisionList 
                                       FROM #Departments tD
                                       JOIN ReportDimReportingHierarchy ReportingHierarchy 
                                         ON ReportingHierarchy.DimReportingHierarchyKey = td.DimReportingHierarchyKey
                                      FOR XML PATH('')),1,1,'') 
DECLARE @HeaderSubdivisionList AS VARCHAR(2000)
SET @HeaderSubdivisionList = STUFF((SELECT DISTINCT ', ' + HeaderSubdivisionList 
                                       FROM #Departments tD
                                       JOIN ReportDimReportingHierarchy ReportingHierarchy 
                                         ON ReportingHierarchy.DimReportingHierarchyKey = td.DimReportingHierarchyKey
                                      FOR XML PATH('')),1,1,'') 
DECLARE @HeaderDepartmentList AS VARCHAR(2000)
SET @HeaderDepartmentList = STUFF((SELECT DISTINCT ', ' + DepartmentName 
                                       FROM #Departments tD
                                       JOIN ReportDimReportingHierarchy ReportingHierarchy 
                                         ON ReportingHierarchy.DimReportingHierarchyKey = td.DimReportingHierarchyKey
                                      FOR XML PATH('')),1,1,'') 
DECLARE @HeaderProductGroupList AS VARCHAR(2000)
SET @HeaderProductGroupList = STUFF((SELECT DISTINCT ', ' + ProductGroupName 
                                       FROM #Departments tD
                                       JOIN ReportDimReportingHierarchy ReportingHierarchy 
                                         ON ReportingHierarchy.DimReportingHierarchyKey = td.DimReportingHierarchyKey
                                      FOR XML PATH('')),1,1,'') 

DECLARE @HeaderRegionList AS VARCHAR(2000) 
SET @HeaderRegionList = REPLACE(@RegionList, '|', ',') 

DECLARE @HeaderClubList AS VARCHAR(2000)
SET @HeaderClubList = STUFF((SELECT DISTINCT ', ' + C.ClubName
                                       FROM #Clubs tC
                                       JOIN vClub C ON C.ClubID = tC.ClubID
                                       FOR XML PATH('')),1,1,'')  

                                       
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
WHERE PlanYear IN (SELECT YEAR FROM #Dates)
  AND ToCurrencyCode = @ReportingCurrencyCode
/***************************************/


SELECT 
       #Dates.YEAR,
       #Dates.MONTH,
       #Dates.MonthDescription,
	   AssessmentYearMonth.FourDigitYearDashTwoDigitMonth,       
	   tcr.RegionName AS Region,       
	   C.ClubCode,	
	   CONVERT(VARCHAR(5),C.ClubID) AS ClubID,
	   C.ClubName, 
	   mrp.MemberID,
	   M.LastName + ' ' + M.FirstName AS MemberName, 
	   M.MembershipID,
	   ReportingHierarchy.DivisionName,
	   ReportingHierarchy.SubdivisionName,
	   ReportingHierarchy.DepartmentName AS DepartmentName, 
  	   ReportingHierarchy.ProductGroupName,
	   P.Description ProductDescription,
	   P.ProductID AS MMSProductID,
	   MRP.Price * #PlanRate.PlanRate Amount,
	   
	   MRP.ActivationDate as ActivationDate,
	   --Replace(SubString(Convert(Varchar, MRP.ActivationDate),1,3)+' '+LTRIM(SubString(Convert(Varchar, MRP.ActivationDate),5,DataLength(Convert(Varchar, MRP.ActivationDate))-12)),' '+Convert(Varchar,Year(MRP.ActivationDate)),', '+Convert(Varchar,Year(MRP.ActivationDate))) as ActivationDate,
	   MRP.TerminationDate as TerminationDate,	
	   --CASE WHEN MRP.TerminationDate IS NULL THEN 'No date end' ELSE Replace(SubString(Convert(Varchar, MRP.TerminationDate),1,3)+' '+LTRIM(SubString(Convert(Varchar, MRP.TerminationDate),5,DataLength(Convert(Varchar, MRP.TerminationDate))-12)),' '+Convert(Varchar,Year(MRP.TerminationDate)),', '+Convert(Varchar,Year(MRP.TerminationDate))) END AS TerminationDate,    
       #Dates.AssessmentDay,
	   NULL AS LastAssessmentDate,
	   CONVERT(DATETIME,NULL) AS PostDate,

	   E.EmployeeID AS CommissionedTeamMemberID,
       CONVERT(VARCHAR(102), E.LastName + ' ' + E.FirstName) AS CommissionedTeamMemberName,
       EC.ClubName AS CommissionedTeamMemberHomeClub,
       CONVERT(DECIMAL(12,2) , 0.00) AS GoalDollarAmount,

       
       @HeaderDivisionList AS HeaderDivisionList,
       @HeaderSubdivisionList AS HeaderSubdivisionList,
       @HeaderDepartmentList AS HeaderDepartmentList,
       @HeaderProductGroupList AS HeaderProductGroupList,

       @HeaderRegionList AS HeaderRegionList,
       @HeaderClubList AS HeaderClubList,
       @ReportingCurrencyCode as ReportingCurrencyCode,
       @ReportRunDateTime AS ReportRunDateTime,

       #Departments.DepartmentMinDimReportingHierarchyKey,
	   #Departments.DimReportingHierarchyKey        
       
  FROM vMembershipRecurrentProduct MRP
  JOIN vValAssessmentDay VAD
    ON ISNULL(MRP.ValAssessmentDayID,1) = VAD.ValAssessmentDayID
  JOIN vClub C
    ON C.ClubID = MRP.ClubID   
  JOIN vProduct P
    ON P.ProductID = MRP.ProductID 
  JOIN vReportDimProduct DimProduct
    ON DimProduct.MMSProductID = P.ProductID
  JOIN vReportDimReportingHierarchy ReportingHierarchy     
    ON ReportingHierarchy.DimReportingHierarchyKey = DimProduct.DimReportingHierarchyKey
  JOIN #RegionClub tCR
    ON tCR.Clubid = C.ClubID
  JOIN #Departments 
    ON #Departments.DimReportingHierarchyKey = ReportingHierarchy.DimReportingHierarchyKey
  JOIN #Dates 
    ON VAD.AssessmentDay = #Dates.AssessmentDay
    AND MRP.ActivationDate <= #Dates.AssessmentDate 
    AND IsNull(MRP.TerminationDate,'Dec 31, 9999') >= #Dates.AssessmentDate
  LEFT JOIN vEmployee E 
    ON E.EmployeeID = MRP.CommissionEmployeeID  
  LEFT JOIN vClub EC 
    ON EC.ClubID = E.ClubID
  LEFT JOIN vMember M -- there are products assigned to a membership, not a specific member like locker rental
	ON M.MemberID = MRP.MemberID 
  JOIN vReportDimDate AssessmentYearMonth
    ON AssessmentYearMonth.CalendarDate = #Dates.AssessmentDate
	
/********** Foreign Currency Stuff **********/
  JOIN vValCurrencyCode VCC
       ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID
  JOIN #PlanRate
       ON VCC.CurrencyCode = #PlanRate.FromCurrencyCode
      AND #Dates.YEAR = #PlanRate.PlanYear  
/*******************************************/
WHERE MRP.ActivationDate < @RecurrentProductEndDate+1 AND  
IsNull(MRP.TerminationDate,'Dec 31, 9999') >= @RecurrentProductStartDate

	DROP TABLE #tmpList 
	DROP TABLE #Clubs 
	DROP TABLE #Departments 
	DROP TABLE #PlanRate	
	DROP TABLE #Dates
	DROP TABLE #Regions
	DROP TABLE #RegionClub
	
END

