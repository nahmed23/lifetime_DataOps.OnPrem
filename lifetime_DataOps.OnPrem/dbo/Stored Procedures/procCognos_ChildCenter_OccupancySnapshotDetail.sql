
CREATE PROC [dbo].[procCognos_ChildCenter_OccupancySnapshotDetail] (
	@MMSClubID INT,
	@ReportStartDate DATETIME,
	@ReportEndDate DATETIME,
	@SnapshotTime VARCHAR(5))

AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

/*************************************************************************
*  procCognos_ChildCenter_OccupancySnapshotDetail
*
*  Returns the Child Center Check-Ins for a given Snapshot of time
*      between the Given date ranges for a particular club
*
*  Note: Assumes the given snapshot was set correctly before being passed
*
*   Test: EXEC [procCognos_ChildCenter_OccupancySnapshotDetail] 36, '2009-08-27', '2009-09-29', '19:30'
*************************************************************************/

--Set Variables used in calculations below
DECLARE @SnapshotTimeHour TINYINT
DECLARE @SnapshotTimeMinute TINYINT 
DECLARE @UTCToday DATETIME
DECLARE @UpdatedEndDate DATETIME
DECLARE @ReportRunDateTime VARCHAR(21)

SET @SnapshotTime = CASE WHEN @SnapshotTime = '99:99' 
	THEN RIGHT('0' + CAST(DATEPART(Hour,getdate()) AS VARCHAR(2)),2) + ':' + RIGHT('0' + CAST(DATEPART(Minute,getdate()) AS VARCHAR(2)),2)
	ELSE @SnapshotTime END
SET @SnapshotTimeHour  = CAST(LEFT(@SnapshotTime,2) AS TINYINT)
SET @SnapshotTimeMinute = CAST(RIGHT(@SnapshotTime,2) AS TINYINT)
SET @UTCToday = CONVERT(DATETIME,CONVERT(VARCHAR(10),GETUTCDATE(),101),101)
SET @ReportRunDateTime = Replace(Substring(convert(varchar,getdate(),100),1,6)+', '+Substring(convert(varchar,getdate(),100),8,10)+' '+Substring(convert(varchar,getdate(),100),18,2),'  ',' ')
SET @ReportStartDate = CASE WHEN @ReportStartDate  = 'Jan 1, 1900' THEN DATEADD(dd, DATEDIFF(dd, 0, getdate()), 0)
	ELSE CONVERT(DATETIME,CONVERT(VARCHAR(10),@ReportStartDate,101),101) END
SET @ReportEndDate = CASE WHEN @ReportEndDate = 'Jan 1, 1900' THEN CONVERT(DATETIME,CONVERT(VARCHAR(10),DATEADD(DD,1,getdate()),101),101)
	ELSE @ReportEndDate END
SET @UpdatedEndDate = CONVERT(DATETIME,CONVERT(VARCHAR(10),DATEADD(DD,1,@ReportEndDate),101),101)

--Create table to hold the Snapshot(s) in the given date range
CREATE TABLE #SnapshotTimes (Time DATETIME)

DECLARE @Time DATETIME
SET @Time = CONVERT(DATETIME,CONVERT(VARCHAR(10),@ReportStartDate,101),101)

IF @SnapshotTimeMinute < 60 --AND @SnapshotTimeMinute % 15 = 0

	WHILE @Time <= @ReportEndDate
	BEGIN
		INSERT INTO #SnapshotTimes (Time)
		SELECT DATEADD(Hour,@SnapshotTimeHour, DATEADD(Minute,@SnapshotTimeMinute, @Time))

		SET @Time = DATEADD(Day,1,@Time)
	END

SELECT @SnapshotTime SnapshotTime,
	   LTrim(Substring(convert(varchar,cast(@SnapShotTime as Datetime),100),13,5)+' '+Substring(convert(varchar,cast(@SnapShotTime as Datetime),100),18,2)) SnapshotTime_AMPM,
       Replace(Substring(convert(varchar,@ReportStartDate,100),1,6)+', '+Substring(convert(varchar,@ReportStartDate,100),8,4),'  ',' ') ReportStartDate,
       Replace(Substring(convert(varchar,@ReportEndDate,100),1,6)+', '+Substring(convert(varchar,@ReportEndDate,100),8,4),'  ',' ') ReportEndDate,
       Club.ClubCode ClubCode,
       PrimaryMember.MemberID PrimaryMemberID,
       PrimaryMember.FirstName PrimaryMemberFirstName,
       PrimaryMember.LastName PrimaryMemberLastName,
       JuniorMember.MemberID JuniorMemberID,
       JuniorMember.FirstName JuniorMemberFirstName,
       JuniorMember.LastName JuniorMemberLastName,
       CAST(DATEDIFF(Year,0,ChildCenterUsage.CheckInDateTime - JuniorMember.DOB)  AS VARCHAR(3)) + ' yrs. ' + CAST(DATEDIFF(Month,0,ChildCenterUsage.CheckInDateTime - JuniorMember.DOB) % 12  AS VARCHAR(3)) + ' mos.' JuniorMemberAge,
       Replace(Substring(convert(varchar,ChildCenterUsage.CheckInDateTime,100),1,6)+', '+Substring(convert(varchar,ChildCenterUsage.CheckInDateTime,100),8,4),'  ',' ') CheckInDate,
       LTrim(Substring(convert(varchar,ChildCenterUsage.CheckInDateTime,100),13,5)+' '+Substring(convert(varchar,ChildCenterUsage.CheckInDateTime,100),18,2)) CheckInTime,
       CheckInMember.FirstName CheckedInBy_FirstName,
       CheckInMember.LastName CheckedInBy_LastName,
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
       CheckOutMember.FirstName CheckedOutBy_FirstName,
       CheckOutMember.LastName CheckedOutBy_LastName,
       CASE WHEN ChildCenterUsage.CheckInDateTime > ISNULL(ChildCenterUsage.CheckOutDateTime,GETDATE()) THEN '0 hrs. 0 mins.'
            WHEN ChildCenterUsage.CheckOutDateTime IS NULL AND CONVERT(DATETIME,CONVERT(VARCHAR(10),ChildCenterUsage.UTCCheckInDateTime,101),101) != @UTCToday
                 THEN CONVERT(VARCHAR,DATEDIFF(MI,ChildCenterUsage.CheckInDateTime,DATEADD(MI,-1,CONVERT(VARCHAR,DATEADD(DD,1,ChildCenterUsage.CheckInDateTime),110)))/60) + ' hrs. ' + CONVERT(VARCHAR,DATEDIFF(MI,ChildCenterUsage.CheckInDateTime,DATEADD(MI,-1,CONVERT(VARCHAR,DATEADD(DD,1,ChildCenterUsage.CheckInDateTime),110))) % 60) + ' mins.'
            WHEN ChildCenterUsage.CheckOutDateTime IS NULL AND CONVERT(DATETIME,CONVERT(VARCHAR(10),ChildCenterUsage.UTCCheckInDateTime,101),101) = @UTCToday
                 THEN CONVERT(VARCHAR,DATEDIFF(MI,ChildCenterUsage.UTCCheckInDateTime,GETUTCDATE())/60) + ' hrs. ' + CONVERT(VARCHAR,DATEDIFF(MI,ChildCenterUsage.UTCCheckInDateTime,GETUTCDATE()) % 60) + ' mins.'
            ELSE CONVERT(VARCHAR,DATEDIFF(MI,ChildCenterUsage.CheckInDateTime,ChildCenterUsage.CheckOutDateTime)/60) + ' hrs. ' + CONVERT(VARCHAR,DATEDIFF(MI,ChildCenterUsage.CheckInDateTime,ChildCenterUsage.CheckOutDateTime) % 60) + ' mins.'
       END LengthOfStay,
       ChildCenterUsage.CheckInDateTime,
	   PartnerMember.MemberID PartnerMemberID,
	   PartnerMember.FirstName PartnerMemberFirstName,
	   PartnerMember.LastName  PartnerMemberLastName,
	   Replace(Substring(convert(varchar,@ReportStartDate,100),1,6)+', '+Substring(convert(varchar,@ReportStartDate,100),8,4),'  ',' ') + ' through ' + Replace(Substring(convert(varchar,@ReportEndDate,100),1,6)+', '+Substring(convert(varchar,@ReportEndDate,100),8,4),'  ',' ') HeaderDateRange,
       @ReportRunDateTime ReportRunDateTime
FROM vChildCenterUsage ChildCenterUsage
JOIN vClub Club
  ON Club.ClubID = ChildCenterUsage.ClubID
JOIN vValTimeZone TimeZone
  ON TimeZone.ValTimeZoneID = Club.ValTimeZoneID
JOIN #SnapshotTimes SnapshotTimes
  ON ChildCenterUsage.CheckInDateTime < SnapshotTimes.Time
 AND ISNULL(ChildCenterUsage.CheckOutDateTime,
				CASE WHEN CONVERT(DATETIME,CONVERT(VARCHAR(10),ChildCenterUsage.UTCCheckInDateTime,101),101) = @UTCToday
					  AND ChildCenterUsage.CheckInDateTimeZone LIKE '%ST'
					 THEN DATEADD(Hour,-1 * TimeZone.STOffset,GETUTCDATE())
					 WHEN CONVERT(DATETIME,CONVERT(VARCHAR(10),ChildCenterUsage.UTCCheckInDateTime,101),101) = @UTCToday
					  AND ChildCenterUsage.CheckInDateTimeZone LIKE '%DT'
					 THEN DATEADD(Hour,-1 * TimeZone.DSTOffset,GETUTCDATE())
					 ELSE DATEADD(Minute, -1,CONVERT(DATETIME,CONVERT(VARCHAR(10),DATEADD(DD,1,ChildCenterUsage.CheckInDateTime),101),101))
				 END) 
>= SnapshotTimes.Time
JOIN vValRegion ValRegion
  ON ValRegion.ValRegionID = Club.ValRegionID
JOIN vMember JuniorMember
  ON JuniorMember.MemberID = ChildCenterUsage.MemberID
JOIN vMember PrimaryMember
  ON PrimaryMember.MembershipID = JuniorMember.MembershipID
 AND PrimaryMember.ValMemberTypeID = 1 --Primary
JOIN vMember CheckInMember
  ON CheckInMember.MemberID = ChildCenterUsage.CheckInMemberID
LEFT JOIN vMember CheckOutMember
  ON CheckOutMember.MemberID = ChildCenterUsage.CheckOutMemberID
LEFT JOIN vMember PartnerMember
  ON PartnerMember.MembershipID = JuniorMember.MembershipID
  AND PartnerMember.ValMemberTypeID = 2 --Partner Member
WHERE ChildCenterUsage.ClubID = @MMSClubID
  AND ChildCenterUsage.CheckInDateTime >= @ReportStartDate
  AND ChildCenterUsage.CheckInDateTime < @UpdatedEndDate
ORDER BY CheckInDate,
		 CheckInTime,
		 JuniorMemberID

DROP TABLE #SnapshotTimes

END

