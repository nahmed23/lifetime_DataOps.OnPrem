
/*************************************************************************
*  procCognos_ChildCenter_CheckedInOverTwoHours
*
*  Returns the Child Center Check-Ins that stayed more than 2 hours
*      between the Given date ranges for the list of clubs and /or optional Member
*
*
*   Test: EXEC [procCognos_ChildCenter_CheckedInOverTwoHours] '2009-05-01', '2009-05-02', '151'
*************************************************************************/

CREATE PROC [dbo].[procCognos_ChildCenter_CheckedInOverTwoHours]
(
	@ReportStartDate DATETIME,
	@ReportEndDate DATETIME,
    @ClubIDList VARCHAR(1000),
	@MemberID INT = NULL
)
AS
BEGIN
SET NOCOUNT ON
SET XACT_ABORT ON

DECLARE @ReportRunDateTime VARCHAR(21)
SET @ReportRunDateTime = Replace(Substring(convert(varchar,getdate(),100),1,6)+', '+Substring(convert(varchar,getdate(),100),8,10)+' '+Substring(convert(varchar,getdate(),100),18,2),'  ',' ')
  
DECLARE @UTCToday DATETIME
SET @UTCToday = CONVERT(DATETIME,CONVERT(VARCHAR(10),GETUTCDATE(),101),101)

-- Parse the ClubIDs into a temp table
CREATE TABLE #tmpList (StringField VARCHAR(50))
CREATE TABLE #Clubs(ClubID INT)
EXEC procParseIntegerList @ClubIDList
INSERT INTO #Clubs(ClubID) SELECT StringField FROM #tmpList
DROP TABLE #tmpList

CREATE TABLE #Members (MemberID INT)
IF @MemberID IS NOT NULL AND ISNULL(@MemberID,0) > 0
   BEGIN
     INSERT INTO #Members (MemberID) 
     SELECT MemberID 
     FROM vMember 
     WHERE MembershipID IN (SELECT MembershipID 
                              FROM vMember 
                            WHERE MemberID = @MemberID)
  END
ELSE
  BEGIN
    INSERT INTO #Members VALUES(-100000000) 
  END

DECLARE @ReportStartDateTime VARCHAR(21),
        @ReportEndDateTime VARCHAR(21)
SELECT @ReportStartDateTime = Replace(Substring(convert(varchar,@ReportStartDate,100),1,6)+', '+Substring(convert(varchar,@ReportStartDate,100),8,10)+' '+Substring(convert(varchar,@ReportStartDate,100),18,2),'  ',' ')
SELECT @ReportEndDateTime = Replace(Substring(convert(varchar,@ReportEndDate,100),1,6)+', '+Substring(convert(varchar,@ReportEndDate,100),8,10)+' '+Substring(convert(varchar,@ReportEndDate,100),18,2),'  ',' ')

SELECT ClubRegion.Description RegionDescription,
       Club.ClubCode ClubCode,
       PrimaryMember.MemberID PrimaryMemberID,
       PrimaryMember.FirstName PrimaryMemberFirstName,
       PrimaryMember.LastName PrimaryMemberLastName,
       ChildMember.MemberID JuniorMemberID,
       ChildMember.FirstName JuniorFirstName,
       ChildMember.LastName JuniorLastName ,
       CAST(DATEDIFF(Year,0,ChildCenterUsage.CheckInDateTime - ChildMember.DOB)  AS VARCHAR(3)) + ' yrs. ' + CAST(DATEDIFF(Month,0,ChildCenterUsage.CheckInDateTime - ChildMember.DOB) % 12  AS VARCHAR(3)) + ' mos.' JuniorMemberAge,
       Replace(Substring(convert(varchar,ChildCenterUsage.CheckInDateTime,100),1,6)+', '+Substring(convert(varchar,ChildCenterUsage.CheckInDateTime,100),8,4),'  ',' ') CheckInDate,
       LTrim(Substring(convert(varchar,ChildCenterUsage.CheckInDateTime,100),13,5)+' '+Substring(convert(varchar,ChildCenterUsage.CheckInDateTime,100),18,2)) CheckInTime,
       CheckInMember.FirstName CheckInBy_FirstName,
       CheckInMember.LastName CheckInBy_LastName,
       CASE WHEN ChildCenterUsage.CheckOutDateTime IS NULL AND CONVERT(DATETIME,CONVERT(VARCHAR(10),ChildCenterUsage.UTCCheckInDateTime,101),101) != @UTCToday
                 THEN Replace(Substring(convert(varchar,ChildCenterUsage.CheckInDateTime,100),1,6)+', '+Substring(convert(varchar,ChildCenterUsage.CheckInDateTime,100),8,4),'  ',' ')
            WHEN ChildCenterUsage.CheckOutDateTime IS NULL AND CONVERT(DATETIME,CONVERT(VARCHAR(10),ChildCenterUsage.UTCCheckInDateTime,101),101) = @UTCToday
                 THEN NULL
            ELSE Replace(Substring(convert(varchar,ChildCenterUsage.CheckOutDateTime,100),1,6)+', '+Substring(convert(varchar,ChildCenterUsage.CheckOutDateTime,100),8,4),'  ',' ')
       END CheckOutDate,
       CASE WHEN ChildCenterUsage.CheckOutDateTime IS NULL AND CONVERT(DATETIME,CONVERT(VARCHAR(10),ChildCenterUsage.UTCCheckInDateTime,101),101) != @UTCToday
                 THEN '11:59 PM'
            WHEN ChildCenterUsage.CheckOutDateTime IS NULL AND CONVERT(DATETIME,CONVERT(VARCHAR(10),ChildCenterUsage.UTCCheckInDateTime,101),101) = @UTCToday
                 THEN NULL
            ELSE LTrim(Substring(convert(varchar,ChildCenterUsage.CheckOutDateTime,100),13,5)+' '+Substring(convert(varchar,ChildCenterUsage.CheckOutDateTime,100),18,2))
       END CheckOutTime,
       CheckOutMember.FirstName CheckOutBy_FirstName,
       CheckOutMember.LastName CheckOutBy_LastName,
       CASE WHEN ChildCenterUsage.CheckInDateTime > ISNULL(ChildCenterUsage.CheckOutDateTime,GETDATE()) THEN '0 hrs. 0 mins.'
            WHEN ChildCenterUsage.CheckOutDateTime IS NULL AND CONVERT(DATETIME,CONVERT(VARCHAR(10),ChildCenterUsage.UTCCheckInDateTime,101),101) != @UTCToday
                 THEN CONVERT(VARCHAR,DATEDIFF(MI,ChildCenterUsage.CheckInDateTime,DATEADD(MI,-1,CONVERT(VARCHAR,DATEADD(DD,1,ChildCenterUsage.CheckInDateTime),110)))/60) + ' hrs. ' + CONVERT(VARCHAR,DATEDIFF(MI,ChildCenterUsage.CheckInDateTime,DATEADD(MI,-1,CONVERT(VARCHAR,DATEADD(DD,1,ChildCenterUsage.CheckInDateTime),110))) % 60) + ' mins.'
            WHEN ChildCenterUsage.CheckOutDateTime IS NULL AND CONVERT(DATETIME,CONVERT(VARCHAR(10),ChildCenterUsage.UTCCheckInDateTime,101),101) = @UTCToday
                 THEN CONVERT(VARCHAR,DATEDIFF(MI,ChildCenterUsage.UTCCheckInDateTime,GETUTCDATE())/60) + ' hrs. ' + CONVERT(VARCHAR,DATEDIFF(MI,ChildCenterUsage.UTCCheckInDateTime,GETUTCDATE()) % 60) + ' mins.'
            ELSE CONVERT(VARCHAR,DATEDIFF(MI,ChildCenterUsage.CheckInDateTime,ChildCenterUsage.CheckOutDateTime)/60) + ' hrs. ' + CONVERT(VARCHAR,DATEDIFF(MI,ChildCenterUsage.CheckInDateTime,ChildCenterUsage.CheckOutDateTime) % 60) + ' mins.'
       END LengthOfStay,
       ChildCenterUsage.ChildCenterUsageID,
       Club.ClubCode + ' - ' + Club.ClubName ClubCode_ClubName ,
       ChildCenterUsage.ClubID MMSClubID,
       ChildCenterUsage.CheckInDateTime CheckInDateTime
  INTO #Results
  FROM vChildCenterUsage ChildCenterUsage
  JOIN #Clubs tmpClub 
    ON  tmpClub.ClubID = ChildCenterUsage.ClubID
  JOIN #Members tmpMember 
    ON (tmpMember.MemberID = ChildCenterUsage.MemberID OR tmpMember.MemberID = -100000000)
  JOIN vClub Club 
    ON Club.ClubID = ChildCenterUsage.ClubID
  JOIN vValRegion ClubRegion 
    ON Club.ValRegionID = ClubRegion.ValRegionID
  JOIN vMember ChildMember 
    ON ChildCenterUsage.MemberID = ChildMember.MemberID
  JOIN vMembership Membership 
    ON ChildMember.MembershipID = Membership.MembershipID
  JOIN vMember PrimaryMember 
    ON Membership.MembershipID = PrimaryMember.MembershipID AND PrimaryMember.ValMemberTypeID = 1
  JOIN vMember CheckInMember 
    ON ChildCenterUsage.CheckInMemberID = CheckInMember.MemberID
  LEFT JOIN vMember CheckOutMember 
    ON ChildCenterUsage.CheckOutMemberID = CheckOutMember.MemberID
 --RETURN ONLY THOSE THAT HAVE MORE THAN 2 HOURS difference BETWEEN CHECKINTIME AND CHECKOUT TIME
  WHERE CASE WHEN ChildCenterUsage.CheckOutDateTime IS NULL AND CONVERT(DATETIME,CONVERT(VARCHAR(10),ChildCenterUsage.UTCCheckInDateTime,101),101) != @UTCToday  --The UTC date of the Check-In is not the same as the Current UTC Date
                THEN DATEDIFF(MI,ChildCenterUsage.UTCCheckInDateTime,GETUTCDATE())
            WHEN ChildCenterUsage.CheckOutDateTime IS NULL AND CONVERT(DATETIME,CONVERT(VARCHAR(10),ChildCenterUsage.UTCCheckInDateTime,101),101) = @UTCToday --The UTC date of the Check-In is the same as the Current UTC Date
                THEN DATEDIFF(MI,ChildCenterUsage.UTCCheckInDateTime,GETUTCDATE())
            ELSE DATEDIFF(MI,ChildCenterUsage.UTCCheckInDateTime,ChildCenterUsage.UTCCheckOutDateTime) END > 120
    AND ChildCenterUsage.CheckInDateTime >= @ReportStartDate
    AND ChildCenterUsage.CheckInDateTime < @ReportEndDate

SELECT @ReportStartDateTime ReportStartDateTime,
       @ReportEndDateTime ReportEndDateTime,
       RegionDescription,
       ClubCode,
       PrimaryMemberID,
       PrimaryMemberFirstName,
       PrimaryMemberLastName,
       JuniorMemberID,
       JuniorFirstName,
       JuniorLastName ,
       JuniorMemberAge,
       CheckInDate,
       CheckInTime,
       CheckInBy_FirstName,
       CheckInBy_LastName,
       CheckOutDate,
       CheckOutTime,
       CheckOutBy_FirstName,
       CheckOutBy_LastName,
       LengthOfStay,
       ChildCenterUsageID,
       ClubCode_ClubName ,
       MMSClubID,
       CheckInDateTime,
       @ReportRunDateTime ReportRunDateTime,
       CAST(NULL AS VARCHAR(70)) HeaderEmptyResultSet
  FROM #Results
 WHERE (SELECT COUNT(*) FROM #Results) > 0
UNION ALL
SELECT @ReportStartDateTime ReportStartDateTime,
       @ReportEndDateTime ReportEndDateTime,
       CAST(NULL AS VARCHAR(50)) RegionDescription,
       CAST(NULL AS VARCHAR(3)) ClubCode,
       CAST(NULL AS INT) PrimaryMemberID,
       CAST(NULL AS VARCHAR(50)) PrimaryMemberFirstName,
       CAST(NULL AS VARCHAR(50)) PrimaryMemberLastName,
       CAST(NULL AS INT) JuniorMemberID,
       CAST(NULL AS VARCHAR(50)) JuniorFirstName,
       CAST(NULL AS VARCHAR(50)) JuniorLastName ,
       CAST(NULL AS VARCHAR(17)) JuniorMemberAge,
       CAST(NULL AS VARCHAR(8000)) CheckInDate,
       CAST(NULL AS VARCHAR(8)) CheckInTime,
       CAST(NULL AS VARCHAR(50)) CheckInBy_FirstName,
       CAST(NULL AS VARCHAR(50)) CheckInBy_LastName,
       CAST(NULL AS VARCHAR(8000)) CheckOutDate,
       CAST(NULL AS VARCHAR(8)) CheckOutTime,
       CAST(NULL AS VARCHAR(50)) CheckOutBy_FirstName,
       CAST(NULL AS VARCHAR(50)) CheckOutBy_LastName,
       CAST(NULL AS VARCHAR(72)) LengthOfStay,
       CAST(NULL AS INT) ChildCenterUsageID,
       CAST(NULL AS VARCHAR(56)) ClubCode_ClubName ,
       CAST(NULL AS INT) MMSClubID,
       CAST(NULL AS DATETIME) CheckInDateTime,
       @ReportRunDateTime ReportRunDateTime,
       'There is no data available for the selected parameters. Please re-try.' HeaderEmptyResultSet
 WHERE (SELECT COUNT(*) FROM #Results) = 0
 ORDER BY MMSClubID,CheckInDate,CheckOutDate,JuniorMemberID





DROP TABLE #Clubs
DROP TABLE #Members
DROP TABLE #Results

END
