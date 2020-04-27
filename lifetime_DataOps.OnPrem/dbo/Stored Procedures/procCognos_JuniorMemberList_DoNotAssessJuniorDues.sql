
CREATE PROC [dbo].[procCognos_JuniorMemberList_DoNotAssessJuniorDues] (
@RegionList  VARCHAR(8000),
@MMSClubIDList VARCHAR(1000)
)

AS
BEGIN 
SET XACT_ABORT ON
SET NOCOUNT ON



------ Sample Execution
---  Exec procCognos_JuniorMemberList_DoNotAssessJuniorDues 'All Regions','151|8'
------

DECLARE @ReportRunDateTime VARCHAR(21)
SET @ReportRunDateTime = Replace(Substring(convert(varchar,GetDate(),100),1,6)+', '+Substring(convert(varchar,GetDate(),100),8,10)+' '+Substring(convert(varchar,GetDate(),100),18,2),'  ',' ')


SELECT DISTINCT Club.ClubID, ValRegion.ValRegionID,Club.AssessJrMemberDuesFlag,Club.ClubName
  INTO #Clubs
  FROM vClub Club
  JOIN fnParsePipeList(@MMSClubIDList) MMSClubIDList
    ON Convert(Varchar,Club.ClubID) = MMSClubIDList.Item
    OR @MMSClubIDList like '%All Clubs%'
  JOIN vValRegion ValRegion
    ON Club.ValRegionID = ValRegion.ValRegionID
  JOIN fnParsePipeList(@RegionList) RegionList
    ON ValRegion.Description = RegionList.Item
      OR @RegionList like '%All Regions%'

Select ValRegion.Description AS Region,
Club.ClubName,
Membership.MembershipID,
PrimaryMember.MemberID AS PrimaryMemberID,
PrimaryMember.FirstName,
PrimaryMember.LastName,
Member.MemberID AS JuniorMemberID,
Member.FirstName AS JuniorFirstName,
Member.LastName AS JuniorLastName,
Member.DOB as JuniorDOB,
CASE WHEN IsNull(Member.AssessJrMemberDuesFlag,2) = 2
     Then ' '
	 When  IsNull(Member.AssessJrMemberDuesFlag,2) = 1
	 THEN 'Y'
	 WHEN IsNull(Member.AssessJrMemberDuesFlag,2) = 0
	 THEN 'N'
	 END AssessJrMemberDuesFlag,
Product.Description as MembershipType,
ValMembershipStatus.Description AS MembershipStatus,
PrimaryMember.EmailAddress AS PrimaryMemberEmailAddress,
MembershipAddress.AddressLine1,
MembershipAddress.AddressLine2,
MembershipAddress.City,
MembershipState.Abbreviation AS State,
MembershipAddress.Zip,
MembershipCountry.Abbreviation AS Country,
@ReportRunDateTime AS ReportRunDateTime
From vMember Member
Join vMembership Membership
On Member.MembershipID = Membership.MembershipID
Join vMembershipType MembershipType
On Membership.MembershipTypeID = MembershipType.MembershipTypeID
JOIN vProduct Product
On MembershipType.ProductID = Product.ProductID
JOIN #Clubs Club
On Membership.ClubID = Club.ClubID
JOIN vValRegion ValRegion
ON Club.ValRegionID = ValRegion.ValRegionID
Join vValMembershipStatus ValMembershipStatus
On Membership.ValMembershipStatusID = ValMembershipStatus.ValMembershipStatusID
JOIN vValMemberType ValMemberType
On Member.ValMemberTypeID = ValMemberType.ValMemberTypeID
JOIN vMember PrimaryMember
ON Membership.MembershipID = PrimaryMember.MembershipID
JOIN vMembershipAddress MembershipAddress
 ON Membership.MembershipID = MembershipAddress.MembershipID
JOIN vValState MembershipState
 ON MembershipAddress.ValStateID = MembershipState.ValStateID 
JOIN vValCountry MembershipCountry
 ON MembershipAddress.ValCountryID = MembershipCountry.ValCountryID
Where ValMembershipStatus.Description in('Active','Suspended')
AND ValMemberType.Description = 'Junior'
AND Member.ActiveFlag = 1
AND PrimaryMember.ValMemberTypeID = 1
AND IsNull(Member.AssessJrMemberDuesFlag,1) = 0
AND IsNull(MembershipType.AssessJrMemberDuesFlag,1) = 1
AND IsNull(Club.AssessJrMemberDuesFlag,1) = 1
AND MembershipAddress.ValAddressTypeID = 1
Order by ValRegion.Description,Club.ClubName,
PrimaryMemberID, JuniorMemberID


DROP TABLE #Clubs




END
