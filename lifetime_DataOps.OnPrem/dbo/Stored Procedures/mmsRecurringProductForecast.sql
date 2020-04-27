
-- =============================================
-- Object:			mmsrRecurrentProductForecast
-- Author:			Ruslan Condratiuc	
-- Create date: 	8/15/2008
-- Description:		Returns all unterminated recurrent products plus any that terminated this month
-- Parameters:      Current Date, Club or List of Clubs, Department or List of Departments
-- Modified Date:	10/12/2009 GRB: added Member Activities Region value to result set per QC #3807 / RR400; deploying 10/14/2009 via dbcr_5139(b)
--					09/29/2011 BSD: added support for multiple assessment days per month QC#7852
--                  10/05/2011 BSD: Proc now accepts multiple prompted assessment dates within a month.
-- 
-- EXEC mmsRecurringProductForecast 'Apr 27, 2011', '141', 'All' 
-- 
-- =============================================

CREATE  PROC [dbo].[mmsRecurringProductForecast] (
	@AssessmentDates VARCHAR(8000),
	@ClubList VARCHAR(8000),	
	@DepartmentList VARCHAR(8000)	)
AS
BEGIN
	
CREATE TABLE #tmpList (StringField VARCHAR(50))
CREATE TABLE #Dates (AssessmentDate DATETIME, AssessmentDay INT, NextMonthAssessmentDate DATETIME)
EXEC procParseStringList @AssessmentDates
INSERT INTO #Dates (AssessmentDate,AssessmentDay, NextMonthAssessmentDate) SELECT StringField, Day(StringField), DateAdd(mm,1,StringField) FROM #tmpList
TRUNCATE TABLE #tmpList

DECLARE @APromptDateTime DATETIME
DECLARE @FirstOfCurrentMonth DateTime
DECLARE @FirstOfNextMonth DateTime

SET @APromptDateTime = (SELECT TOP 1 AssessmentDate FROM #Dates)
SET @FirstOfCurrentMonth = DATEADD(mm,DATEDIFF(mm,0,@APromptDateTime),0)
SET @FirstOfNextMonth = DATEADD(mm,DATEDIFF(mm,0,DATEADD(mm,1,@APromptDateTime)),0)

CREATE TABLE #Clubs (ClubID VARCHAR(50))
IF @ClubList <> 'All'
 BEGIN -- Parse the ClubIDs into a temp table
  EXEC procParseIntegerList @ClubList
  INSERT INTO #Clubs (ClubID) SELECT StringField FROM #tmpList
  TRUNCATE TABLE #tmpList
 END
ELSE
 BEGIN
  INSERT INTO #Clubs (ClubID) SELECT ClubID FROM vClub
 END

CREATE TABLE #Departments (DepartmentID VARCHAR(50))
IF @DepartmentList <> 'All'
 BEGIN -- Parse the ClubIDs into a temp table
  EXEC procParseIntegerList @DepartmentList
  INSERT INTO #Departments (DepartmentID) SELECT StringField FROM #tmpList
  TRUNCATE TABLE #tmpList
 END
ELSE
 BEGIN
  INSERT INTO #Departments (DepartmentID) SELECT DepartmentID FROM vDepartment
 END

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
WHERE PlanYear >= Year(@APromptDateTime)  
  AND ToCurrencyCode = @ReportingCurrencyCode

CREATE TABLE #ToUSDPlanRate (PlanRate DECIMAL(14,4), FromCurrencyCode VARCHAR(15), PlanYear INT)
INSERT INTO #ToUSDPlanRate
SELECT PlanExchangeRate, FromCurrencyCode, PlanYear
FROM PlanExchangeRate
WHERE PlanYear >= Year(@APromptDateTime)
  AND ToCurrencyCode = 'USD'
/***************************************/

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

SELECT VR.Description AS Region,
	   c.ClubCode,	
	   MRP.ClubID, 
	   C.ClubName, 
	   D.Description AS Department, 
	   MRP.CommissionEmployeeID, 
	   E.LastName AS EmployeeLastName, 
	   E.FirstName AS EmployeeFirstName, 
	   E.MiddleInt AS EmployeeMiddleInt,
	   CASE WHEN (MRP.CommissionEmployeeID IS NOT NULL AND MRP.CommissionEmployeeID <>0) THEN E.LastName +', '+ E.FirstName + ' '+ E.MiddleInt ELSE ' None Designated' END CommisionedEmployee, 
	   CASE WHEN (MRP.MemberID IS NOT NULL AND MRP.MemberID<>0) THEN MRP.MemberID ELSE PrimaryMember.MemberID END MemberID, 
	   MRP.MembershipID,
	   CASE WHEN (MRP.MemberID IS NOT NULL AND MRP.MemberID<>0) THEN M.FirstName ELSE PrimaryMember.FirstName END MemberFirstName, 
	   CASE WHEN (MRP.MemberID IS NOT NULL AND MRP.MemberID<>0) THEN M.LastName ELSE PrimaryMember.LastName END MemberLastName,
	   CASE WHEN (MRP.MemberID IS NOT NULL AND MRP.MemberID<>0) THEN M.MiddleName ELSE PrimaryMember.MiddleName END MemberMiddleName,
	   P.DepartmentID,
	   D.Description AS DepartmentDescription,
	   MRP.ProductID, 
	   P.Description ProductDescription,
	   -- this month amount
	   ISNULL(CASE WHEN (MRP.ActivationDate <= #Dates.AssessmentDate AND IsNull(MRP.TerminationDate,'Dec 31, 9999') >= #Dates.AssessmentDate)THEN MRP.Price * #PlanRate.PlanRate END,0) ThisMonthAmount, 
	   ISNULL(CASE WHEN (MRP.ActivationDate <= #Dates.AssessmentDate AND IsNull(MRP.TerminationDate,'Dec 31, 9999') >= #Dates.AssessmentDate) THEN MRP.Price END,0) LocalCurrency_ThisMonthAmount, 
	   ISNULL(CASE WHEN (MRP.ActivationDate <= #Dates.AssessmentDate AND IsNull(MRP.TerminationDate,'Dec 31, 9999') >= #Dates.AssessmentDate) THEN MRP.Price * #ToUSDPlanRate.PlanRate END,0) USD_ThisMonthAmount, 
	   -- next month amount
	   ISNULL(CASE WHEN (MRP.ActivationDate <= #Dates.NextMonthAssessmentDate AND IsNull(MRP.TerminationDate,'Dec 31, 9999') >= #Dates.NextMonthAssessmentDate) THEN MRP.Price * #PlanRate.PlanRate END,0) NextMonthAmount, 
	   ISNULL(CASE WHEN (MRP.ActivationDate <= #Dates.NextMonthAssessmentDate AND IsNull(MRP.TerminationDate,'Dec 31, 9999') >= #Dates.NextMonthAssessmentDate) THEN MRP.Price END,0) LocalCurrency_NextMonthAmount, 
	   ISNULL(CASE WHEN (MRP.ActivationDate <= #Dates.NextMonthAssessmentDate AND IsNull(MRP.TerminationDate,'Dec 31, 9999') >= #Dates.NextMonthAssessmentDate) THEN MRP.Price * #ToUSDPlanRate.PlanRate END,0) USD_NextMonthAmount, 
	   MRP.ActivationDate as ActivationDate_Sort,
	   Replace(SubString(Convert(Varchar, MRP.ActivationDate),1,3)+' '+LTRIM(SubString(Convert(Varchar, MRP.ActivationDate),5,DataLength(Convert(Varchar, MRP.ActivationDate))-12)),' '+Convert(Varchar,Year(MRP.ActivationDate)),', '+Convert(Varchar,Year(MRP.ActivationDate))) as ActivationDate,
	   MRP.TerminationDate as TerminationDate_Sort,		
	   Replace(SubString(Convert(Varchar, MRP.TerminationDate),1,3)+' '+LTRIM(SubString(Convert(Varchar, MRP.TerminationDate),5,DataLength(Convert(Varchar, MRP.TerminationDate))-12)),' '+Convert(Varchar,Year(MRP.TerminationDate)),', '+Convert(Varchar,Year(MRP.TerminationDate))) as TerminationDate,    
	   ISNULL(DATEDIFF(month, @FirstOfCurrentMonth, MRP.TerminationDate),0) AS NumberOfMonthsLeft,
	   ISNULL((DATEDIFF(month, @FirstOfCurrentMonth, MRP.TerminationDate)) * (MRP.Price * #PlanRate.PlanRate), 0) AS TotalAmountLeft,
	   ISNULL((DATEDIFF(month, @FirstOfCurrentMonth, MRP.TerminationDate)) * MRP.Price, 0) AS LocalCurrency_TotalAmountLeft,
	   ISNULL((DATEDIFF(month, @FirstOfCurrentMonth, MRP.TerminationDate)) * (MRP.Price * #ToUSDPlanRate.PlanRate), 0) AS USD_TotalAmountLeft,
	   VMAR.Description [MemberActivityRegion],
	   VCC.CurrencyCode as LocalCurrencyCode,
       #PlanRate.PlanRate,
       @ReportingCurrencyCode as ReportingCurrencyCode, 	
       VAD.ValAssessmentDayID,
       Replace(Substring(convert(varchar,#Dates.AssessmentDate,100),1,6)+', '+Substring(convert(varchar,#Dates.AssessmentDate,100),8,4),'  ',' ') AssessmentDate,
       Replace(Substring(convert(varchar,#Dates.NextMonthAssessmentDate,100),1,6)+', '+Substring(convert(varchar,#Dates.NextMonthAssessmentDate,100),8,4),'  ',' ') AssessmentDate_NextMonth,
       Replace(@AssessmentDates,'|',', ') HeaderAssessmentDates,
       MembershipProduct.Description MembershipType,
       ValMembershipStatus.Description MembershipStatus
  FROM vMembershipRecurrentProduct MRP
  JOIN vValAssessmentDay VAD
    ON ISNULL(MRP.ValAssessmentDayID,1) = VAD.ValAssessmentDayID
  JOIN vClub C
    ON C.ClubID = MRP.ClubID
  JOIN vValRegion VR
    ON VR.ValRegionID = C.ValRegionID
  JOIN vValMemberActivityRegion VMAR
    ON C.ValMemberActivityRegionID = VMAR.ValMemberActivityRegionID
  JOIN vProduct P
    ON P.ProductID = MRP.ProductID
  JOIN vDepartment D
    ON D.DepartmentID = P.DepartmentID
  LEFT JOIN vEmployee E
    ON E.EmployeeID = MRP.CommissionEmployeeID
  LEFT JOIN vMember M
    ON M.MemberID = MRP.MemberID
-- if member ID is null or 0 then select primary member on a membership
  JOIN vMember PrimaryMember
    ON PrimaryMember.MembershipID = MRP.MembershipID
  JOIN vValMemberType ValMT
    ON ValMT.valMemberTypeID = PrimaryMember.valMemberTypeID and ValMT.Description = 'Primary'
-- QC#2559
  JOIN vMembership Membership
    ON MRP.MembershipID = Membership.MembershipID
  JOIN vValMembershipStatus ValMembershipStatus
    ON Membership.ValMembershipStatusID = ValMembershipStatus.ValMembershipStatusID
  JOIN vMembershipType MembershipType
    ON Membership.MembershipTypeID = MembershipType.MembershipTypeID
  JOIN vProduct MembershipProduct
    ON MembershipType.ProductID = MembershipProduct.ProductID
-- filters
  JOIN #Clubs tC
    ON tC.ClubID = C.ClubID
  JOIN #Departments tD
    ON tD.DepartmentID = D.DepartmentID
  JOIN #Dates ON VAD.AssessmentDay = #Dates.AssessmentDay
/********** Foreign Currency Stuff **********/
  JOIN vValCurrencyCode VCC
       ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID
  JOIN #PlanRate
       ON VCC.CurrencyCode = #PlanRate.FromCurrencyCode
      AND YEAR(@APromptDateTime) = #PlanRate.PlanYear
  JOIN #ToUSDPlanRate
       ON VCC.CurrencyCode = #ToUSDPlanRate.FromCurrencyCode
      AND YEAR(@APromptDateTime) = #ToUSDPlanRate.PlanYear
/*******************************************/
WHERE ((MRP.ActivationDate <= #Dates.AssessmentDate AND IsNull(MRP.TerminationDate,'Dec 31, 9999') >= #Dates.AssessmentDate)
       OR
       (MRP.ActivationDate <= #Dates.NextMonthAssessmentDate AND IsNull(MRP.TerminationDate,'Dec 31, 9999') >= #Dates.NextMonthAssessmentDate))
ORDER BY mrp.terminationdate desc

	DROP TABLE #tmpList 
	DROP TABLE #Clubs 
	DROP TABLE #Departments 
	DROP TABLE #PlanRate
	DROP TABLE #ToUSDPlanRate
	DROP TABLE #Dates

	-- Report Logging
	  UPDATE HyperionReportLog
	  SET EndDateTime = getdate()
	  WHERE ReportLogID = @Identity

END

