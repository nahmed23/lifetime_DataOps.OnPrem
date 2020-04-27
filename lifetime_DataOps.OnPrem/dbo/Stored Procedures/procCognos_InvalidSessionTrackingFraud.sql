

CREATE  PROC [dbo].[procCognos_InvalidSessionTrackingFraud] 
(
	@DeliveredDateStart SMALLDATETIME,
	@DeliveredDateEND SMALLDATETIME,
	@ClubIDList VARCHAR(8000),
	@MMSDepartmentIDList VARCHAR(1000),
	@myLTBucksFilter VARCHAR(50),
	@AreaList VARCHAR(8000) 	
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

IF 1=0 BEGIN
       SET FMTONLY OFF
     END
----- Description: Returns a list of PT sessions that  were checked off for members that did not check into 
-----  			   club that same day prior to the session checked-off time
----- Sample Execution
--- Exec procCognos_InvalidSessionTrackingFraud '10/1/2016','10/15/2016','151|8','9','Not Limited by myLT Buck$','All Areas'
-----


SET @DeliveredDateStart = CASE WHEN @DeliveredDateStart = 'Jan 1, 1900' 
                      THEN DATEADD(MONTH,DATEDIFF(MONTH,0,GETDATE()-1),0)    ----- Translates to 1st of yesterday's month
					  ELSE @DeliveredDateStart END
SET @DeliveredDateEND = CASE WHEN @DeliveredDateEND = 'Jan 1, 1900'          ----- Translates to yesterday's date
                    THEN CONVERT(DATETIME,CONVERT(VARCHAR,GETDATE()-1,101),101) 
					ELSE @DeliveredDateEND END



DECLARE @FirstOfPriorMonth DateTime
SET @FirstOfPriorMonth = (Select CalendarPriorMonthStartingDate From vReportDimDate Where CalendarDate = @DeliveredDateStart)


DECLARE @HeaderDateRange VARCHAR(33), @ReportRunDateTime VARCHAR(21), @HeaderDepartmentList VARCHAR(2000) 
SET @HeaderDateRange = convert(varchar(12), @DeliveredDateStart, 107) + ' to ' + convert(varchar(12), @DeliveredDateEND, 107)
SET @ReportRunDateTime = Replace(Substring(convert(varchar,getdate(),100),1,6)+', '+Substring(convert(varchar,GETDATE(),100),8,10)+' '+Substring(convert(varchar,getdate(),100),18,2),'  ',' ')

DECLARE @AdjDeliveredDateEnd DateTime
SET @AdjDeliveredDateEnd = DATEADD(DAY,1,@DeliveredDateEND) -- include full day

	-- SELECTED CLUBS
	CREATE TABLE #tmpList (StringField VARCHAR(50))

  SELECT DISTINCT Club.ClubID as ClubID
  INTO #Clubs
  FROM vClub Club
  JOIN fnParsePipeList(@ClubIDList) MMSClubIDList
    ON Convert(Varchar,Club.ClubID) = MMSClubIDList.Item
    OR @ClubIDList like '%All Clubs%'
  JOIN vValPTRCLArea Area
    On Club.ValPTRCLAreaID = Area.ValPTRCLAreaID
  JOIN fnParsePipeList(@AreaList) AreaList
    ON Area.Description = AreaList.Item
    OR @AreaList like '%All Areas%'
	
	-- Selected Departments
    EXEC procParseIntegerList @MMSDepartmentIDList
    CREATE TABLE #Departments (DepartmentID INT)INSERT INTO #Departments (DepartmentID) SELECT StringField FROM #tmpList
 
    SET @HeaderDepartmentList = STUFF((SELECT DISTINCT ', ' + D.Description 
                                       FROM #Departments #D
                                       JOIN vDepartment D ON D.DepartmentID = #D.DepartmentID
                                       FOR XML PATH('')),1,1,'') 
	
	

	----- to reduce processing time by limiting valid Employees to non-terminated ones
	SELECT EmployeeID,
	  FirstName,
	  LastName,
	  MiddleInt
	  INTO #NonTermEmployees
	 FROM vEmployee 
	 WHERE IsNull(TerminationDate,@AdjDeliveredDateEnd) >= @DeliveredDateStart

	 ----- to reduce processing time by first limiting sessions to those in date range and selected clubs
	 SELECT PS.PackageSessionID,
	        PS.DeliveredDateTime,
			PS.PackageID,
			PS.DeliveredEmployeeID,
            PS.ClubID
	  INTO #PeriodSessions
	 FROM vPackageSession PS
	 	JOIN #Clubs C 
		ON C.ClubID = PS.clubid
	WHERE PS.DeliveredDateTime >= @DeliveredDateStart 
	  AND PS.DeliveredDateTime < @AdjDeliveredDateEnd


	SELECT 
	PS.PackageSessionID,	
	PK.memberid AS MemberID,
	PTRCL.Description AS PTRCLAreaName, 
	C.ValPTRCLAreaID, 
    C.ClubName, 
    C.ClubID,     
    E.FirstName AS EmpFirstName, 
    E.LastName AS EmpLastName, 
    E.MiddleInt AS EmpMiddleName, 
	P.Description AS PackageSession, 
	PS.DeliveredDateTime as SessionCheckOff_Sort, 	
	Replace(Substring(convert(varchar,PS.DeliveredDateTime,100),1,6)+', '+Substring(convert(varchar,PS.DeliveredDateTime,100),8,10)+' '+Substring(convert(varchar,PS.DeliveredDateTime,100),18,2),'  ',' ') as SessionCheckOff,
	M.FirstName AS MemberFirstName, 
	M.LastName AS MemberLastName, 
	M.MiddleName AS MemberMiddleName,
	@HeaderDateRange AS HeaderDateRange,
	@ReportRunDateTime AS ReportRunDateTime,
	@myLTBucksFilter as HeaderMyLTBucks,
	@HeaderDepartmentList as HeaderDepartmentList,
	M.JoinDate  As MemberJoinDate,
	M.MembershipID,
	hier.SubdivisionName,
	hier.DepartmentName
	INTO #ResultSet
	FROM #PeriodSessions PS
	JOIN vPackage PK
		ON PK.PackageID = PS.PackageID
	JOIN vProduct P
		ON P.ProductID = PK.ProductID
    JOIN vReportDimProduct RDP
	    ON P.ProductID = RDP.MMSProductID
	JOIN #NonTermEmployees E
	    ON E.EmployeeID = PS.deliveredemployeeid
	JOIN vClub C
		ON C.ClubID = PS.ClubID
	JOIN vValPTRCLArea PTRCL
		ON PTRCL.ValPTRCLAreaID = c.ValPTRCLAreaID
	JOIN vMember M
		ON M.MemberID = PK.MemberID
	JOIN #Departments #D
	    ON P.DepartmentID = #D.DepartmentID
    LEFT JOIN [dbo].ReportDimReportingHierarchy hier on RDP.DimReportingHierarchyKey = hier.DimReportingHierarchyKey
	WHERE RDP.RevenueReportingDepartmentName <> 'Large Group'
	  AND RDP.RevenueProductGroupName <> 'Pilates Group'
	  AND PS.DeliveredDateTime >= DateAdd(day,1,(Convert(datetime,convert(varchar(12),M.JoinDate, 107))))   ---- Do not count sessions delivered on the member join date 
	  AND PS.DeliveredDateTime <(
		SELECT                                       ------ if this script finds a matching date, that date(time truncated) will be less than the full delivered datetime - no record returned
		COALESCE(min(convert(datetime,convert(varchar(12),MU.UsageDateTime,101))),'2050-12-31')   ---- if it does not find a matching date, 12/31/2050 will be greater than the delivered datetime and return the record
		FROM vMemberUsage MU 
		WHERE 
		-- select all records (check ins) for a given date 
		convert(datetime,convert(varchar(12),PS.DeliveredDateTime,101)) = convert(datetime,convert(varchar(12),MU.UsageDateTime,101))
		and PK.MemberID = MU.MemberID
	    )
	 AND (
		   (PK.EmployeeID = -5 and @myLTBucksFilter = 'myLT Buck$ Only')
			OR
		   (PK.EmployeeID is Null and @myLTBucksFilter ='Exclude myLT Buck$')
			OR
		   (PK.EmployeeID <> -5 and @myLTBucksFilter ='Exclude myLT Buck$')
			OR
		   (@myLTBucksFilter = 'Not Limited by myLT Buck$'))


 ----- To gather resulting Memeber IDs for members with invalid session tracking

	SELECT MemberID,Cast(SessionCheckOff_Sort AS Date) AS SessionDate
	 INTO #MemberIDList
	 FROM #ResultSet
	 GROUP BY MemberID,Cast(SessionCheckOff_Sort AS Date)

 ----- Looking back for these members to the 1st of the prior month to see when the last check-in was for each of these members

 SELECT MU.MemberID, 
        IDList.SessionDate, 
		Max(MU.UsageDateTime) MostRecentCheckInDateTime
	INTO #MostRecentCheckIn
 FROM vMemberUsage MU
  JOIN #MemberIDList IDList
    ON MU.MemberID = IDList.MemberID
 WHERE MU.UsageDateTime < IDList.SessionDate
  AND MU.UsageDateTime >= @FirstOfPriorMonth
  GROUP BY MU.MemberID,IDList.SessionDate

----- Bring back full result set appending the most recent check-in Date
  	SELECT 
	RS.PackageSessionID,	
	RS.MemberID,
	RS.PTRCLAreaName, 
	RS.ValPTRCLAreaID, 
    RS.ClubName, 
    RS.ClubID,     
    RS.EmpFirstName, 
    RS.EmpLastName, 
    RS.EmpMiddleName, 
	RS.PackageSession, 
	RS.SessionCheckOff_Sort, 	
	RS.SessionCheckOff,
	RS.MemberFirstName, 
	RS.MemberLastName, 
	RS.MemberMiddleName,
	RS.HeaderDateRange,
	RS.ReportRunDateTime,
	RS.HeaderMyLTBucks,
	RS.HeaderDepartmentList,
	RS.MemberJoinDate,
	RS.MembershipID,
	MS.ExpirationDate AS MembershipTerminationDate,
	MRCI.MostRecentCheckInDateTime,
	@FirstOfPriorMonth AS CheckInLookBackDate,
	RS.SubdivisionName,
	RS.DepartmentName
	FROM #ResultSet RS
	 JOIN vMembership MS
	   ON RS.MembershipID = MS.MembershipID
	 LEFT JOIN #MostRecentCheckIn MRCI
	   ON RS.MemberID = MRCI.MemberID
	     AND Cast(RS.SessionCheckOff_Sort AS Date) = MRCI.SessionDate
 
		   
	DROP TABLE #tmpList 
	DROP TABLE #Clubs 
	DROP TABLE #Departments
	DROP TABLE #NonTermEmployees
	DROP TABLE #PeriodSessions
	DROP TABLE #ResultSet
	DROP TABLE #MemberIDList
	DROP TABLE #MostRecentCheckIn
	
END




