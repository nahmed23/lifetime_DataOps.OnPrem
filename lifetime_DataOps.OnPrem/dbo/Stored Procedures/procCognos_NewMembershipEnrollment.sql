
CREATE PROC [dbo].[procCognos_NewMembershipEnrollment] (
    @StartDate DATETIME,
    @EndDate DATETIME,
    @MMSClubIDList VARCHAR(8000)
)

AS
BEGIN 
SET XACT_ABORT ON
SET NOCOUNT ON


DECLARE    @AdjustedStartDate SMALLDATETIME
DECLARE    @AdjustedEndDate SMALLDATETIME

SET @AdjustedStartDate = DateAdd(day,-1,@StartDate)
SET @AdjustedEndDate = DateAdd(day,1,@EndDate)


SELECT DISTINCT item MMSClubID
  INTO #MMSClubIDList
  FROM fnParsePipeList(@MMSClubIDList)


DECLARE @ReportRunDateTime VARCHAR(21)
SET @ReportRunDateTime = Replace(Substring(convert(varchar,GetDate(),100),1,6)+', '+Substring(convert(varchar,GetDate(),100),8,10)+' '+Substring(convert(varchar,GetDate(),100),18,2),'  ',' ')

DECLARE @HeaderMembershipCreatedDateRange VARCHAR(110)
SET @HeaderMembershipCreatedDateRange = Replace(Substring(convert(varchar,@StartDate,100),1,6)+', '+Substring(convert(varchar,@StartDate,100),8,4),'  ',' ')
                       + '  through  ' + 
                       Replace(Substring(convert(varchar,@EndDate,100),1,6)+', '+Substring(convert(varchar,@EndDate,100),8,4),'  ',' ')

  --- Gather all enrollment fee transactions within the adjusted date range for memberships in the selected clubs
Select MT.MembershipID, MT.IPAddress,MT.PostDateTime
INTO #MembershipEnrollmentTran_IPAddress
From vMMSTran MT
Join vTranItem TI
On MT.MMSTranID = TI.MMSTranID
Join vMembership MS
On MT.MembershipID = MS.MembershipID
Join #MMSClubIDList #MMSClubIDList
On MS.ClubID = #MMSClubIDList.MMSClubID
Where TI.ProductID = 88                      -------- Enrollment Fee transaction
AND MT.PostDateTime >= @AdjustedStartDate
AND MT.PostDateTime < @AdjustedEndDate


  -----  Gather information on all club memberships created in the period
SELECT MS.MembershipID,
       R.Description as MMSRegion, 
       C.ClubName as MembershipClub, 
	   MS.CreatedDateTime,
       M.MemberID as PrimaryMemberID,
	   M.FirstName as PrimaryMemberFirstName,
	   M.LastName as PrimaryMemberLastName, 
	   VMSS.Description SourceDescription, 
       E.EmployeeID AdvisorEmployeeID, 
	   E.FirstName AdvisorFirstname, 
	   E.LastName AdvisorLastname,
	   VET.Description as EnrollmentType,
	   #IP.IPAddress as EnrollmentFeeTransaction_IPAddress, 
	   #IP.PostDateTime as EnrollmentFeePostDateTime,
	   @ReportRunDateTime as ReportRunDateTime,
	   @HeaderMembershipCreatedDateRange as HeaderMembershipCreatedDateRange
  FROM dbo.vClub C
  JOIN dbo.vMembership MS
       ON MS.ClubID = C.ClubID
  JOIN #MMSClubIDList #MMSClubIDList
       ON MS.ClubID = #MMSClubIDList.MMSClubID
  JOIN vValRegion R
       ON C.ValRegionID = R.ValRegionID
  JOIN dbo.vMember M
       ON M.MembershipID = MS.MembershipID
  JOIN dbo.vValMembershipSource VMSS
       ON MS.ValMembershipSourceID = VMSS.ValMembershipSourceID
  JOIN dbo.vEmployee E 
       ON MS.AdvisorEmployeeID = E.EmployeeID
  Left Join vValEnrollmentType VET
       ON MS.ValEnrollmentTypeID = VET.ValEnrollmentTypeID
  Left Join #MembershipEnrollmentTran_IPAddress  #IP
       ON MS.MembershipID = #IP.MembershipID
 WHERE MS.CreatedDateTime >= @StartDate 
       AND MS.CreatedDateTime < @AdjustedEndDate 
	   AND M.ValMemberTypeID = 1


	   Drop Table #MembershipEnrollmentTran_IPAddress
	   Drop Table #MMSClubIDList

END
