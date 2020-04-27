
CREATE PROC [dbo].[procCognos_ExpectedRosterCancellations] (
   @InterestList Varchar(1000),
   @MMSClubIDList VARCHAR(4000)
   )

AS
BEGIN 
SET XACT_ABORT ON
SET NOCOUNT ON

 IF 1=0 BEGIN
       SET FMTONLY OFF
     END


------- Sample Execution
----- Exec procCognos_ExpectedRosterCancellations '3|6','151|180'
-------


 ------- NOTE:   Because the BOSS and Report_MMS databases are used in this query, there are 4 lines that need to be commented/uncommented when 
 -------         Moving code between Dev, QA and PROD 



DECLARE @ReportDate DateTime
SET @ReportDate = getdate()



  -----   Report is always real time
DECLARE @OneMonthAfter DateTime
SET @OneMonthAfter = DateAdd(month,1,@ReportDate)


 ----- Create a temp table of all selected BOSS interests
SELECT Cast(item as Int) InterestID
  INTO #BOSSInterestIDList
  FROM fnParsePipeList(@InterestList)
  GROUP BY item



  DECLARE @HeaderSelectedInterestList AS VARCHAR(2000)
  SET @HeaderSelectedInterestList = STUFF((SELECT ', ' + RTRIM(Interest.long_desc)
                                       FROM [BOSS].[dbo].[interest] Interest                    --------Comment out when in Dev/QA
									   -----FROM [Sandbox_Int].[rep].[BOSS_Interests] Interest              --------Comment out when in PROD
                                       JOIN #BOSSInterestIDList tI ON Interest.id = tI.InterestID
									   ORDER BY Interest.long_desc
                                       FOR XML PATH('')),1,1,'')   

        
 
 
 ------ Create a temp table of all selected clubs
SELECT Cast(item as Int) MMSClubID
  INTO #MMSClubIDList
  FROM fnParsePipeList(@MMSClubIDList)
  GROUP BY item

  ----- Find members who are on active rosters who are either inactive or on memberships which have a membership termination date up to one month in the future
Select DailyRoster.mbr_code AS MemberID,
	Membership.MembershipID,
	Membership.ExpirationDate AS MembershipExpirationDate,
	Member.ActiveFlag,
	Club.ClubID,
	Club.ClubCode,
	Count(DailyRoster.meeting_date) AS ClassCountLeftOnRoster,
	MembershipStatus.Description AS MembershipStatus,
	DailyRoster.description AS RosterClass,
	DailyRoster.instructor AS ClassInstructor,
	Member.FirstName,
	Member.LastName,
	Region.Description AS MMSRegion,
	Club.ClubName
INTO #OutstandingRoster
FROM [BOSS].[dbo].[dailyRoster] DailyRoster                              ------Comment out when in DEV/QA
-----FROM [Sandbox_Int].[rep].BOSS_DailyRoster_Sample DailyRoster     ------Comment out when in PROD
JOIN #BOSSInterestIDList InterestList
  ON CAST(DailyRoster.interest_id as INT) = InterestList.InterestID
JOIN #MMSClubIDList SelectedClubs
  ON CAST(DailyRoster.club as INT) = SelectedClubs.MMSClubID
JOIN vMember Member 
  ON  Member.MemberID = Cast(DailyRoster.mbr_code as INT)
JOIN vMembership Membership 
  ON Membership.MembershipID = Member.MembershipID
JOIN vClub Club 
  ON Club.ClubID = Cast(DailyRoster.club as INT)
JOIN vValRegion Region
  ON Club.ValRegionID = Region.ValRegionID
JOIN vValMembershipStatus MembershipStatus 
  ON MembershipStatus.ValMembershipStatusID = Membership.ValMembershipStatusID

WHERE DailyRoster.meeting_date > @ReportDate
  AND ((Membership.ExpirationDate <= @OneMonthAfter) 
        OR ((IsNull(Membership.Expirationdate,'1/1/1900') = '1/1/1900' AND  Member.ActiveFlag = 0) 
		     OR Membership.ValMembershipStatusID = 3))
  AND (IsNull(Membership.Expirationdate,'1/1/1900') = '1/1/1900' OR Membership.ActivationDate < Membership.ExpirationDate )
  AND DailyRoster.mbr_code > 0

group by DailyRoster.mbr_code,
	Membership.MembershipID,
	Membership.ExpirationDate,
	Member.ActiveFlag,
	Club.ClubID,
	Club.ClubCode,
	MembershipStatus.Description,
	DailyRoster.description,
	DailyRoster.instructor,
	Member.FirstName,
	Member.LastName,
	Region.Description,
	Club.ClubName


  ----- Get a distinct list of the above members

	Select Distinct MemberID
	INTO #CancellingMemberIDs
	FROM #OutstandingRoster


  ----- Which of these members also have an active recurrent product schedule
SELECT MRP.MemberID,
	Product.Description  AS RecurrentProduct,
	MRP.ActivationDate AS RecurrentProductStartDate,
	MRP.TerminationDate AS RecurrentProductEndDate,
	MRP.ProductHoldBeginDate AS RecurrentProductHoldStartDate,
	MRP.ProductHoldEndDate AS RecurrentProductHoldEndDate,
	AssessmentDay.AssessmentDay AS RecurrentProductAssessmentDayOfMonth
 INTO #OutstandingRecurrentProductSchedules
FROM vMembershipRecurrentProduct MRP
JOIN #CancellingMemberIDs CancellingMemberIDs
  ON MRP.MemberID = CancellingMemberIDs.MemberID
JOIN vProduct Product
  ON MRP.ProductID = Product.ProductID
JOIN vValAssessmentDay AssessmentDay
  ON MRP.ValAssessmentDayID = AssessmentDay.ValAssessmentDayID
WHERE Product.Description <> 'Experience Life Subscription'
 AND IsNull(MRP.TerminationDate,@ReportDate+1) > @ReportDate



 ----- Combine data, adding any recurrent product information to the cancelling roster members
 SELECT OutstandingRoster.MembershipID,
	OutstandingRoster.MemberID,
	OutstandingRoster.FirstName,
	OutstandingRoster.LastName,
	OutstandingRoster.MembershipExpirationDate,
	OutstandingRoster.ClubCode,
	OutstandingRoster.MembershipStatus,
	CASE WHEN OutstandingRoster.ActiveFlag = 1
	     THEN 'Active'
		 ELSE 'Inactive'
		 END MemberStatus,
	OutstandingRoster.RosterClass,
	OutstandingRoster.ClassInstructor AS RosterClassInstructor,
	OutstandingRoster.ClassCountLeftOnRoster,
	RecurrentProductSchedule.RecurrentProduct,
	RecurrentProductSchedule.RecurrentProductStartDate,
	RecurrentProductSchedule.RecurrentProductEndDate,
	RecurrentProductSchedule.RecurrentProductHoldStartDate,
	RecurrentProductSchedule.RecurrentProductHoldEndDate,
	RecurrentProductSchedule.RecurrentProductAssessmentDayOfMonth,
	@HeaderSelectedInterestList as HeaderSelectedInterestList,
	OutstandingRoster.MMSRegion,
	OutstandingRoster.ClubName,
	@ReportDate AS ReportDateTime
  FROM #CancellingMemberIDs CancellingMemberIDs
   JOIN #OutstandingRoster OutstandingRoster
     ON CancellingMemberIDs.MemberID = OutstandingRoster.MemberID
   LEFT JOIN #OutstandingRecurrentProductSchedules RecurrentProductSchedule
     ON CancellingMemberIDs.MemberID = RecurrentProductSchedule.MemberID
  




	DROP TABLE  #BOSSInterestIDList
	DROP TABLE  #MMSClubIDList
	DROP TABLE  #OutstandingRoster
	DROP TABLE  #CancellingMemberIDs
	DROP TABLE  #OutstandingRecurrentProductSchedules


END
