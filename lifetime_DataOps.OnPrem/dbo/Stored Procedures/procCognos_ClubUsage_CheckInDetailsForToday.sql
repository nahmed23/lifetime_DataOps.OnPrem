
---------------------------------------------------------------------------------------
---- Sample execution
---- exec procCognos_ClubUsage_CheckInDetailsForToday '1/5/2016','1/15/2016','10','Male|Undefined'
---------------------------------------------------------------------------------------

CREATE PROCEDURE [dbo].[procCognos_ClubUsage_CheckInDetailsForToday] (
		@StartDate Datetime,
		@EndDate Datetime,
		@CheckInMMSClubIDList VARCHAR(1000),
		@GenderList VARCHAR(100)
)

AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON


Declare @AdjCheckInEndDate Datetime
SET @AdjCheckInEndDate = DateAdd(Day,1,@EndDate)

DECLARE @ReportRunDateTime VARCHAR(21)
SET @ReportRunDateTime = Replace(Substring(convert(varchar,getdate(),100),1,6)+', '+Substring(convert(varchar,getdate(),100),8,10)+' '+Substring(convert(varchar,getdate(),100),18,2),'  ',' ')

DECLARE @GenderCommaList VARCHAR(4000)
SET @GenderCommaList = Replace(@GenderList,'|',',')


CREATE TABLE #tmpList (StringField VARCHAR(15))
CREATE TABLE #Clubs (ClubID VARCHAR(15))
CREATE TABLE #Gender (Gender VARCHAR(15))

IF @CheckInMMSClubIDList <> 'All'
BEGIN
	EXEC procParseStringList @CheckInMMSClubIDList --inserts ClubIds into #tmpList
    INSERT INTO #Clubs (ClubID) SELECT StringField FROM #tmpList
    TRUNCATE TABLE #tmpList
END
ELSE
BEGIN
	INSERT INTO #Clubs select clubid from vClub
END
 

BEGIN
	EXEC procParseStringList @GenderList --inserts Gender selections into #tmpList
    INSERT INTO #Gender (Gender) SELECT StringField FROM #tmpList
    TRUNCATE TABLE #tmpList
END


SELECT ValMembershipTypeAttributeID,
       Description MembershipStatusSummaryTypeGroup
  INTO #MembershipStatusSummaryTypeGroups
  FROM vValMembershipTypeAttribute
 WHERE Description like 'Membership Status Summary Group%'

SELECT UsageClub.ClubName AS CheckInClubName, 
       UsageClub.ClubCode AS CheckInClubCode, 
   	   CONVERT(date,MemberUsage.UsageDateTime) CheckInDate,
	   CONVERT(time,MemberUsage.UsageDateTime) CheckInTime,
       MembershipClub.ClubName AS HomeClubName,
       MembershipClub.ClubCode AS HomeClubCode,
       Member.MembershipID, 
       Member.MemberID,
       '' AS GuestID,
       Member.FirstName as MemberFirstName, 
       Member.LastName as MemberLastName,
       CASE Member.Gender 
	     WHEN 'M' 
		 THEN 'Male' 
		 WHEN 'F' 
		 THEN 'Female' 
		 ELSE 'Undefined' 
		 End As GenderDescription,
       ValMemberType.Description as MemberOrGuestType,
       CAST(DATEDIFF(yy,Member.DOB,MemberUsage.UsageDateTime) - CASE WHEN DATEPART(dy,Member.DOB) > DATEPART(dy,MemberUsage.UsageDateTime) THEN 1 ELSE 0 END as Varchar) as MemberAge,
       MemberUsage.UsageDateTime CheckIn_DateTime,
       @ReportRunDateTime ReportRunDateTime,
       Product.Description MembershipType,
       ValCheckInGroup.Description CheckInGroup,
	   CASE WHEN IsNull(ValRevenueReportingCategory.Description,'No Sales Promotion') = 'No Sales Promotion'
               THEN #MembershipStatusSummaryTypeGroups.MembershipStatusSummaryTypeGroup
                    ELSE ValRevenueReportingCategory.Description
                    END MembershipStatusSummaryTypeGroup,
       UsageDepartment.Description NonAccessCheckInDepartment,
	   @StartDate as HeaderReportStartDate,
	   @EndDate as HeaderReportEndDate,
	   @GenderCommaList as HeaderReportGender
  INTO #Results
  FROM vMember Member
  JOIN vMemberUsage MemberUsage
    ON MemberUsage.MemberID = Member.MemberID
  JOIN #Clubs
    ON #Clubs.ClubID = MemberUsage.ClubID
  JOIN dbo.vClub UsageClub
    ON UsageClub.ClubID = #Clubs.ClubID AND UsageClub.DisplayUIFlag = 1
  JOIN dbo.vMembership Membership
    ON Member.MembershipID = Membership.MembershipID
  JOIN dbo.vClub MembershipClub
    ON Membership.ClubID = MembershipClub.ClubID
  JOIN dbo.vValMemberType ValMemberType
    ON Member.ValMemberTypeID = ValMemberType.ValMemberTypeID
  JOIN vMembershipType MembershipType
    ON Membership.MembershipTypeID = MembershipType.MembershipTypeID  
  JOIN vProduct Product
    ON MembershipType.ProductID = Product.ProductID  
  JOIN vValCheckInGroup ValCheckInGroup
    ON MembershipType.ValCheckInGroupID = ValCheckInGroup.ValCheckInGroupID
  JOIN vMembershipTypeAttribute MembershipTypeAttribute
    ON MembershipType.MembershipTypeID = MembershipTypeAttribute.MembershipTypeID
  LEFT JOIN vMembershipAttribute  MembershipAttribute
    ON Membership.MembershipID = MembershipAttribute.MembershipID
       AND MembershipAttribute.ValMembershipAttributeTypeID = 3   ---- PromotionID
  LEFT JOIN vSalesPromotion  SalesPromotion
    ON MembershipAttribute.AttributeValue = SalesPromotion.SalesPromotionID
  LEFT JOIN vValRevenueReportingCategory  ValRevenueReportingCategory 
    ON SalesPromotion.ValRevenueReportingCategoryID = ValRevenueReportingCategory.ValRevenueReportingCategoryID
  JOIN #MembershipStatusSummaryTypeGroups
    ON MembershipTypeAttribute.ValMembershipTypeAttributeID = #MembershipStatusSummaryTypeGroups.ValMembershipTypeAttributeID
  LEFT JOIN vDepartment UsageDepartment
    ON MemberUsage.DepartmentID = UsageDepartment.DepartmentID
 WHERE MemberUsage.UsageDateTime >= @StartDate
       AND MemberUsage.UsageDateTime < @AdjCheckInEndDate


UNION ALL

SELECT GuestUsageClub.ClubName AS CheckInClubName, 
       GuestUsageClub.ClubCode AS CheckInClubCode, 
       CONVERT(date,GuestVisit.VisitDateTime) CheckInDate,
	   CONVERT(time,GuestVisit.VisitDateTime) CheckInTime,
	   MembershipClub.ClubName AS HomeClubName,
       MembershipClub.ClubCode AS HomeClubCode,
       CASE GuestVisit.MemberID WHEN NULL THEN '' ELSE Member.MembershipID End As MembershipID,
       CASE GuestVisit.MemberID WHEN NULL THEN '' ELSE GuestVisit.MemberID END AS MemberID,
       Cast(GuestVisit.GuestID as Varchar(20)) AS GuestID,
       '' as MemberFirstName, 
       '' as MemberLastName,
       'Undefined' As GenderDescription,
       'Guest' as MemberOrGuestType,
       '' AS MemberAge,
       GuestVisit.VisitDateTime CheckIn_DateTime,
       @ReportRunDateTime ReportRunDateTime,
       Product.Description MembershipType,
       ValCheckInGroup.Description CheckInGroup,
	   CASE WHEN IsNull(ValRevenueReportingCategory.Description,'No Sales Promotion') = 'No Sales Promotion'
               THEN #MembershipStatusSummaryTypeGroups.MembershipStatusSummaryTypeGroup
                    ELSE ValRevenueReportingCategory.Description
                    END MembershipStatusSummaryTypeGroup,
       NULL NonAccessCheckInDepartment,
	   @StartDate as HeaderReportStartDate,
	   @EndDate as HeaderReportEndDate,
	   @GenderList as HeaderReportGender
  FROM vGuestVisit GuestVisit
  JOIN #Clubs
    ON #Clubs.ClubID = GuestVisit.ClubID
  JOIN dbo.vClub GuestUsageClub
    ON GuestUsageClub.ClubID = #Clubs.ClubID and GuestUsageClub.DisplayUIFlag = 1
  LEFT JOIN vMember Member
    ON GuestVisit.MemberID = Member.MemberID
  LEFT JOIN vMembership Membership
    ON Member.MembershipID = Membership.MembershipID
  LEFT JOIN dbo.vClub MembershipClub
    ON Membership.ClubID = MembershipClub.ClubID
  LEFT JOIN vMembershipType MembershipType
    ON Membership.MembershipTypeID = MembershipType.MembershipTypeID  
  LEFT JOIN vProduct Product
    ON MembershipType.ProductID = Product.ProductID  
  LEFT JOIN vValCheckInGroup ValCheckInGroup
    ON MembershipType.ValCheckInGroupID = ValCheckInGroup.ValCheckInGroupID  
  LEFT JOIN vMembershipTypeAttribute MembershipTypeAttribute
    ON MembershipType.MembershipTypeID = MembershipTypeAttribute.MembershipTypeID
  LEFT JOIN vMembershipAttribute  MembershipAttribute
    ON Membership.MembershipID = MembershipAttribute.MembershipID
       AND MembershipAttribute.ValMembershipAttributeTypeID = 3   ---- PromotionID
  LEFT JOIN vSalesPromotion  SalesPromotion
    ON MembershipAttribute.AttributeValue = SalesPromotion.SalesPromotionID
  LEFT JOIN vValRevenueReportingCategory  ValRevenueReportingCategory 
    ON SalesPromotion.ValRevenueReportingCategoryID = ValRevenueReportingCategory.ValRevenueReportingCategoryID
  LEFT JOIN #MembershipStatusSummaryTypeGroups
    ON MembershipTypeAttribute.ValMembershipTypeAttributeID = #MembershipStatusSummaryTypeGroups.ValMembershipTypeAttributeID 
  WHERE GuestVisit.VisitDateTime >= @StartDate
       AND GuestVisit.VisitDateTime < @AdjCheckInEndDate


 Select CheckInClubName, 
       CheckInClubCode, 
       CheckInDate,
	   CheckInTime,
	   HomeClubName,
       HomeClubCode,
       MembershipID,
       MemberID,
       GuestID,
       MemberFirstName, 
       MemberLastName,
       GenderDescription,
       MemberOrGuestType,
       MemberAge,
       CheckIn_DateTime,
       ReportRunDateTime,
       MembershipType,
       CheckInGroup,
	   MembershipStatusSummaryTypeGroup,
       NonAccessCheckInDepartment,
	   HeaderReportStartDate,
	   HeaderReportEndDate,
	   HeaderReportGender
 From #Results
 Join #Gender 
 On #Results.GenderDescription = #Gender.Gender


DROP TABLE #tmpList
DROP TABLE #Clubs
DROP TABLE #MembershipStatusSummaryTypeGroups
DROP TABLE #Results
DROP TABLE #Gender


END



