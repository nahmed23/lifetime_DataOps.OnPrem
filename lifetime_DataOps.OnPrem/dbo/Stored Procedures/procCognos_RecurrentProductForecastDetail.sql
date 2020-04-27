


CREATE  PROC [dbo].[procCognos_RecurrentProductForecastDetail] (
	@AssessmentDates VARCHAR(8000),
	@RegionList VARCHAR(2000),
	@ClubIDList VARCHAR(8000),	
	@DepartmentMinDimReportingHierarchyKeyList VARCHAR(8000),
	@ProductID INT -- one product at a time for detail report
)	
AS
BEGIN

IF 1=0 BEGIN
       SET FMTONLY OFF
     END

---- Sample Execution
-- EXEC procCognos_RecurrentProductForecastDetail '11/17/2016|11/18/2016|11/19/2016|11/20/2016|11/21/2016|11/22/2016|11/23/2016|11/24/2016|11/25/2016|11/26/2016|11/27/2016|11/28/2016', 'MN Greenig', '151|195|197', '220',  0
----

DECLARE @ReportRunDateTime VARCHAR(21) 
SET @ReportRunDateTime = Replace(Substring(convert(varchar,getdate(),100),1,6)+', '+Substring(convert(varchar,GETDATE(),100),8,10)+' '+Substring(convert(varchar,getdate(),100),18,2),'  ',' ')
	
CREATE TABLE #tmpList (StringField VARCHAR(50))
CREATE TABLE #Dates (AssessmentDate DATETIME, AssessmentDay INT, NextMonthAssessmentDate DATETIME)
EXEC procParseStringList @AssessmentDates
INSERT INTO #Dates (AssessmentDate,AssessmentDay, NextMonthAssessmentDate) SELECT convert(date,StringField,101), Day(StringField), DateAdd(mm,1,StringField) FROM #tmpList
TRUNCATE TABLE #tmpList

DECLARE @APromptDateTime DATETIME
DECLARE @FirstOfCurrentMonth DateTime
DECLARE @FirstOfNextMonth DateTime

SET @APromptDateTime = (SELECT TOP 1 AssessmentDate FROM #Dates)
SET @FirstOfCurrentMonth = DATEADD(mm,DATEDIFF(mm,0,@APromptDateTime),0)
SET @FirstOfNextMonth = DATEADD(mm,DATEDIFF(mm,0,DATEADD(mm,1,@APromptDateTime)),0)

DECLARE @StartMonthStartingDimDateKey INT,
        @EndMonthEndingDimDateKey INT        

SELECT @StartMonthStartingDimDateKey  = MonthStartingDimDateKey,
       @EndMonthEndingDimDateKey = MonthEndingDimDateKey
FROM vReportDimDate
WHERE CalendarDate = @FirstOfCurrentMonth

CREATE TABLE #Regions (RegionName VARCHAR(50))
EXEC procParseStringList @RegionList
INSERT INTO #Regions (RegionName) SELECT StringField FROM #tmpList
TRUNCATE TABLE #tmpList


  
  -- Parse the ClubIDs into a temp table  
CREATE TABLE #Clubs (ClubID VARCHAR(50))
IF @ClubIDList like '%All Clubs%'
  BEGIN
  INSERT INTO #Clubs (ClubID) SELECT ClubID FROM vClub
 END
 ELSE
 BEGIN 
  EXEC procParseIntegerList @ClubIDList
  INSERT INTO #Clubs (ClubID) SELECT StringField FROM #tmpList
  TRUNCATE TABLE #tmpList
 END


SELECT DISTINCT
       DimReportingHierarchyKey,
       HeaderDivisionList,
       HeaderSubdivisionList,
       HeaderDepartmentList,
       HeaderProductGroupList,
       ReportRegionType
  INTO #Departments
  FROM fnRevenueDimReportingHierarchy('n/a', 'n/a', @DepartmentMinDimReportingHierarchyKeyList,'n/a',@StartMonthStartingDimDateKey,@EndMonthEndingDimDateKey)

DECLARE @RegionType VARCHAR(50)
SELECT @RegionType = MIN(ReportRegionType) FROM #Departments


CREATE TABLE #RegionClub (Clubid INT, ClubName VARCHAR(50), RegionName VARCHAR(50))
INSERT INTO #RegionClub 
  SELECT C.Clubid, ClubName, 
         CASE WHEN Description IS NULL THEN 'None Designated' ELSE Description END RegionName
  FROM vClub C
  LEFT JOIN vValRegion MMSR 
    ON MMSR.valregionid = C.valregionid
  JOIN #Clubs tC 
    ON tC.ClubID = C.ClubID
  JOIN #Regions tR 
    ON tR.RegionName = MMSR.Description OR MMSR.Description IS NULL
  WHERE @RegionType = 'MMS Region'
UNION 
  SELECT C.Clubid, ClubName, 
         CASE WHEN Description IS NULL THEN 'None Designated' ELSE Description END RegionName
  FROM vClub C
  LEFT JOIN vvalptrclarea PTR 
    ON PTR.valptrclareaid = C.ValPTRCLAreaID
  JOIN #Clubs tC 
    ON tC.ClubID = C.ClubID
  JOIN #Regions tR 
    ON tR.RegionName = PTR.Description OR PTR.Description IS NULL
  WHERE @RegionType = 'PT RCL Area'
UNION
  SELECT C.Clubid, ClubName, 
         CASE WHEN Description IS NULL THEN 'None Designated' ELSE Description END RegionName
  FROM vClub C
  LEFT JOIN vValMemberActivityRegion MAR 
    ON MAR.ValMemberActivityRegionID = C.ValMemberActivityRegionID
  JOIN #Clubs tC 
    ON tC.ClubID = C.ClubID
  JOIN #Regions tR 
    ON tR.RegionName = MAR.Description OR MAR.Description IS NULL
  WHERE @RegionType = 'Member Activities Region'
ORDER BY ClubID


DECLARE @HeaderDepartmentList AS VARCHAR(2000)
SET @HeaderDepartmentList = STUFF((SELECT DISTINCT ', ' + DepartmentName 
                                       FROM #Departments tD
                                       JOIN ReportDimReportingHierarchy ReportingHierarchy 
                                         ON ReportingHierarchy.DimReportingHierarchyKey = td.DimReportingHierarchyKey
                                      FOR XML PATH('')),1,1,'') 

DECLARE @HeaderRegionList AS VARCHAR(2000) 
SET @HeaderRegionList = REPLACE(@RegionList, '|', ',') 


SELECT 
       tcr.RegionName AS Region,
	   C.ClubCode,	
	   C.ClubID, 
	   C.ClubName, 
	   ReportingHierarchy.DepartmentName AS Department, 
	   #Departments.DimReportingHierarchyKey,
       -- report columns  
	   CASE WHEN (MRP.MemberID IS NOT NULL AND MRP.MemberID<>0) 
	        THEN MRP.MemberID 
			ELSE PrimaryMember.MemberID 
			END MemberID, 
       ValMembershipStatus.Description MembershipStatus,
	   CASE WHEN (MRP.MemberID IS NOT NULL AND MRP.MemberID<>0) 
	        THEN M.FirstName 
			ELSE PrimaryMember.FirstName 
			END MemberFirstName, 
	   CASE WHEN (MRP.MemberID IS NOT NULL AND MRP.MemberID<>0) 
	        THEN M.LastName 
			ELSE PrimaryMember.LastName 
			END MemberLastName,
	   CASE WHEN (MRP.MemberID IS NOT NULL AND MRP.MemberID<>0) 
	        THEN M.MiddleName 
			ELSE PrimaryMember.MiddleName 
			END MemberMiddleName,
       MembershipProduct.Description MembershipType,
	   P.Description ProductDescription,
	   P.ProductID,
	   ISNULL(CASE WHEN (MRP.ActivationDate <= #Dates.AssessmentDate 
                          AND IsNull(MRP.TerminationDate,'Dec 31, 9999') >= #Dates.AssessmentDate)
						  AND (
		                        (IsNull(MRP.ProductHoldBeginDate,'Jan 1,1900')< #Dates.AssessmentDate AND IsNull(MRP.ProductHoldEndDate,'Jan 1,1900')< #Dates.AssessmentDate)
		                     OR (IsNull(MRP.ProductHoldBeginDate,'Dec 31, 9999')> #Dates.AssessmentDate AND IsNull(MRP.ProductHoldEndDate,'Dec 31, 9999')> #Dates.AssessmentDate)
			                   )
				   THEN MRP.Price  
				   END,0) ThisMonthAmount,
	   ISNULL(CASE WHEN (MRP.ActivationDate <= #Dates.NextMonthAssessmentDate 
	                      AND IsNull(MRP.TerminationDate,'Dec 31, 9999') >= #Dates.NextMonthAssessmentDate) 
						  AND (
		                        (IsNull(MRP.ProductHoldBeginDate,'Jan 1,1900')< #Dates.NextMonthAssessmentDate AND IsNull(MRP.ProductHoldEndDate,'Jan 1,1900')< #Dates.NextMonthAssessmentDate)
		                      OR (IsNull(MRP.ProductHoldBeginDate,'Dec 31, 9999')> #Dates.NextMonthAssessmentDate AND IsNull(MRP.ProductHoldEndDate,'Dec 31, 9999')> #Dates.NextMonthAssessmentDate)
                              )
				   THEN MRP.Price 
				   END,0) NextMonthAmount,
	   MRP.ActivationDate as ActivationDate_Sort,
	   Replace(SubString(Convert(Varchar, MRP.ActivationDate),1,3)+' '+LTRIM(SubString(Convert(Varchar, MRP.ActivationDate),5,DataLength(Convert(Varchar, MRP.ActivationDate))-12)),' '+Convert(Varchar,Year(MRP.ActivationDate)),', '+Convert(Varchar,Year(MRP.ActivationDate))) as ActivationDate,
	   MRP.TerminationDate as TerminationDate_Sort,	
	   CASE WHEN MRP.Terminationdate IS NULL 
	        THEN 'No date end' 
			ELSE Replace(SubString(Convert(Varchar, MRP.TerminationDate),1,3)+' '+LTRIM(SubString(Convert(Varchar, MRP.TerminationDate),5,DataLength(Convert(Varchar, MRP.TerminationDate))-12)),' '+Convert(Varchar,Year(MRP.TerminationDate)),', '+Convert(Varchar,Year(MRP.TerminationDate))) 
			END AS TerminationDate,    
       MRP.ProductHoldBeginDate AS ProductHoldBeginDate_Sort,
	   Replace(SubString(Convert(Varchar, MRP.ProductHoldBeginDate),1,3)+' '+LTRIM(SubString(Convert(Varchar, MRP.ProductHoldBeginDate),5,DataLength(Convert(Varchar, MRP.ProductHoldBeginDate))-12)),' '+Convert(Varchar,Year(MRP.ProductHoldBeginDate)),', '+Convert(Varchar,Year(MRP.ProductHoldBeginDate))) as ProductHoldBeginDate,
	   MRP.ProductHoldEndDate AS ProductHoldEndDate_Sort,
	   Replace(SubString(Convert(Varchar, MRP.ProductHoldEndDate),1,3)+' '+LTRIM(SubString(Convert(Varchar, MRP.ProductHoldEndDate),5,DataLength(Convert(Varchar, MRP.ProductHoldEndDate))-12)),' '+Convert(Varchar,Year(MRP.ProductHoldEndDate)),', '+Convert(Varchar,Year(MRP.ProductHoldEndDate))) as ProductHoldEndDate,
	   CASE WHEN IsNull(MRP.ProductHoldBeginDate,'1/1/1900') = '1/1/1900'
	        THEN ISNULL(DATEDIFF(month, @FirstOfCurrentMonth, MRP.TerminationDate),0)
			WHEN IsNull(MRP.Terminationdate,'1/1/1900') = '1/1/1900'
			THEN 0
			WHEN MRP.ProductHoldEndDate < #Dates.AssessmentDate
			THEN ISNULL(DATEDIFF(month, @FirstOfCurrentMonth, MRP.TerminationDate),0)
			WHEN MRP.ProductHoldEndDate >= #Dates.AssessmentDate
			THEN (ISNULL(DATEDIFF(month, @FirstOfCurrentMonth, MRP.TerminationDate),0)) - DATEDIFF(month, #Dates.AssessmentDate, MRP.ProductHoldEndDate)
			END NumberOfMonthsLeft,
	   CASE WHEN IsNull(MRP.ProductHoldBeginDate,'1/1/1900') = '1/1/1900'
	        THEN ISNULL((DATEDIFF(month, @FirstOfCurrentMonth, MRP.TerminationDate)) * MRP.Price, 0)
			WHEN IsNull(MRP.Terminationdate,'1/1/1900') = '1/1/1900'
			THEN 0
			WHEN MRP.ProductHoldEndDate < #Dates.AssessmentDate
			THEN ISNULL((DATEDIFF(month, @FirstOfCurrentMonth, MRP.TerminationDate)) * MRP.Price, 0)
			WHEN MRP.ProductHoldEndDate >= #Dates.AssessmentDate
			THEN ISNULL((DATEDIFF(month, @FirstOfCurrentMonth, MRP.TerminationDate)) * MRP.Price, 0) - (DATEDIFF(month, #Dates.AssessmentDate, MRP.ProductHoldEndDate)* MRP.Price)
			END TotalAmountLeft,
	   CASE WHEN (MRP.CommissionEmployeeID IS NOT NULL AND MRP.CommissionEmployeeID <>0) 
	        THEN E.LastName +', '+ E.FirstName + ' '+ E.MiddleInt 
			ELSE ' None Designated' 
			END CommisionedEmployee,     
       MRP.CommissionEmployeeID,
	   MRP.CreatedDateTime, 
       E.LastName AS EmployeeLastName, 
	   E.FirstName AS EmployeeFirstName, 
	   E.MiddleInt AS EmployeeMiddleInt,      	   
       Replace(@AssessmentDates,'|',', ') HeaderAssessmentDates,
       @HeaderDepartmentList AS HeaderDepartmentList,
       'Local Currency' as ReportingCurrencyCode,
       @ReportRunDateTime AS ReportRunDateTime,
	   Membership.ExpirationDate AS MembershipTerminationDate,
       VAD.AssessmentDay AS AssessmentDayOfMonth
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
  LEFT JOIN vEmployee E
    ON E.EmployeeID = MRP.CommissionEmployeeID
  LEFT JOIN vMember M
    ON M.MemberID = MRP.MemberID
-- if member ID is null or 0 then select primary member on a membership
  JOIN vMember PrimaryMember
    ON PrimaryMember.MembershipID = MRP.MembershipID
  JOIN vValMemberType ValMT
    ON ValMT.valMemberTypeID = PrimaryMember.valMemberTypeID and ValMT.Description = 'Primary'

  JOIN vMembership Membership
    ON MRP.MembershipID = Membership.MembershipID
  JOIN vValMembershipStatus ValMembershipStatus
    ON Membership.ValMembershipStatusID = ValMembershipStatus.ValMembershipStatusID
  JOIN vMembershipType MembershipType
    ON Membership.MembershipTypeID = MembershipType.MembershipTypeID
  JOIN vProduct MembershipProduct
    ON MembershipType.ProductID = MembershipProduct.ProductID

-- filters

  JOIN #RegionClub tCR
    ON tCR.Clubid = C.ClubID
  JOIN #Departments 
    ON #Departments.DimReportingHierarchyKey = ReportingHierarchy.DimReportingHierarchyKey
  JOIN #Dates ON VAD.AssessmentDay = #Dates.AssessmentDay

WHERE ((MRP.ActivationDate <= #Dates.AssessmentDate AND IsNull(MRP.TerminationDate,'Dec 31, 9999') >= #Dates.AssessmentDate)
       OR
       (MRP.ActivationDate <= #Dates.NextMonthAssessmentDate AND IsNull(MRP.TerminationDate,'Dec 31, 9999') >= #Dates.NextMonthAssessmentDate))
       AND (@ProductID = 0 or P.ProductID = @ProductID)

ORDER BY mrp.terminationdate desc

	DROP TABLE #tmpList 
	DROP TABLE #Clubs 
	DROP TABLE #Departments 
	DROP TABLE #Dates
	DROP TABLE #Regions
	DROP TABLE #RegionClub
	
END





