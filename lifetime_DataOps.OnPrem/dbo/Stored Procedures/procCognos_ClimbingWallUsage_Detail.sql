
CREATE PROC [dbo].[procCognos_ClimbingWallUsage_Detail] (
 @StartDate DateTime,
 @EndDate DateTime,
 @RegionList VARCHAR(1000),
 @ClubIDList Varchar(25)
)

AS
BEGIN 
SET XACT_ABORT ON
SET NOCOUNT ON

 ----------------------------------------------------------------------------------------
 ---- Sample Execution
 ---  Exec procCognos_ClimbingWallUsage_Detail '1/1/2016','2/1/2016','All Regions','151'
 ----------------------------------------------------------------------------------------

DECLARE @AdjustedEndDate DateTime
SET @AdjustedEndDate = DateAdd(day,1,@EndDate)


SELECT DISTINCT Club.ClubID as ClubID
  INTO #Clubs
  FROM vClub Club
  JOIN fnParsePipeList(@ClubIDList) MMSClubIDList
    ON Convert(Varchar,Club.ClubID) = MMSClubIDList.Item
    OR @ClubIDList like '%All Clubs%'
  JOIN vValRegion Region
    On Club.ValRegionID = Region.ValRegionID
  JOIN fnParsePipeList(@RegionList) RegionList
    ON Region.Description = RegionList.Item
    OR @RegionList like '%All Regions%'



SELECT Club.ClubCode
	  ,ClubActivityAreaMemberUsage.[MemberID]
      ,Member.FirstName
	  ,Member.LastName
	  ,convert(date,ClubActivityAreaMemberUsage.UsageDateTime)as UsageDate
      ,convert(Time,ClubActivityAreaMemberUsage.UsageDateTime) as UsageTime
      ,DateDiff(Year,Member.DOB,getdate()) as Age
	  ,@StartDate ReportStartDate
	  ,@EndDate ReportEndDate

  FROM vClubActivityAreaMemberUsage as ClubActivityAreaMemberUsage
  JOIN vClub as Club 
    ON ClubActivityAreaMemberUsage.ClubID=Club.ClubID
  JOIN #Clubs  UsageClub
    ON UsageClub.ClubID = Club.ClubID
  JOIN dbo.vMember as Member
    ON ClubActivityAreaMemberUsage.MemberID = Member.MemberID
  WHERE ClubActivityAreaMemberUsage.ValActivityAreaID='2' and     ------ Rockwall area ID
     ClubActivityAreaMemberUsage.UsageDateTime>=@StartDate and 
     ClubActivityAreaMemberUsage.UsageDateTime <=@AdjustedEndDate

	ORDER BY Club.ClubCode,ClubActivityAreaMemberUsage.UsageDateTime


	DROP TABLE #Clubs

END
