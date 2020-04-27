
CREATE PROC [dbo].[procCognos_ChildCenter_Evacuation] (
	@MMSClubID INT)

AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

SELECT Club.ClubCode 'Club Code'
       ,Replace(Substring(convert(varchar,ChildCenterUsage.CheckInDateTime,100),1,6)+', '+Substring(convert(varchar,ChildCenterUsage.CheckInDateTime,100),8,4),'  ',' ') 'Check In Date'
       ,LTrim(Substring(convert(varchar,ChildCenterUsage.CheckInDateTime,100),13,5)+' '+Substring(convert(varchar,ChildCenterUsage.CheckInDateTime,100),18,2)) 'Check In Time'
       ,Club.ClubName 'Club Name'
       ,rtrim(JuniorMember.FirstName) + ' ' +  rtrim(JuniorMember.LastName) 'Junior Member'
	   ,PrimaryMember.MemberID 'Primary Member ID'
       ,rtrim(CheckInMember.FirstName)  + ' ' +  rtrim(CheckInMember.LastName) 'Checked In By'
       ,rtrim(PrimaryMember.FirstName)  + ' ' +  rtrim(PrimaryMember.LastName) 'Primary Member'
	   ,PartnerMember.MemberID 'Partner Member ID'
	   ,rtrim(PartnerMember.FirstName)  + ' ' +  rtrim(PartnerMember.LastName) 'Partner Member'
       ,ChildCenterUsage.CheckOutDateTime 'Check Out DateTime'
FROM vChildCenterUsage ChildCenterUsage
JOIN vClub Club
  ON Club.ClubID = ChildCenterUsage.ClubID
JOIN vMember JuniorMember
  ON JuniorMember.MemberID = ChildCenterUsage.MemberID --Junior Member
JOIN vMember PrimaryMember
  ON PrimaryMember.MembershipID = JuniorMember.MembershipID
     AND PrimaryMember.ValMemberTypeID = 1 --Primary Member
JOIN vMember CheckInMember
  ON CheckInMember.MemberID = ChildCenterUsage.CheckInMemberID
LEFT JOIN vMember CheckOutMember
  ON CheckOutMember.MemberID = ChildCenterUsage.CheckOutMemberID
LEFT JOIN vMember PartnerMember
  ON PartnerMember.MembershipID = JuniorMember.MembershipID
     AND PartnerMember.ValMemberTypeID = 2 --Partner Member
WHERE ChildCenterUsage.ClubID = @MMSClubID
  AND ISNULL(ChildCenterUsage.CheckOutDateTime,'1900-01-01') = '1900-01-01' -- Check out DT is null (not checked out)
  AND ChildCenterUsage.CheckInDateTime >= CONVERT(DATETIME,CONVERT(VARCHAR(10),GETDATE(),101),101)  -- Midnight Central Current Day

END
