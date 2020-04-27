

CREATE PROC [dbo].[procCognos_MembershipInformationDetail_JuniorDues] (
    @DateFilter VARCHAR(50),
    @ReportStartDate DATETIME,
    @ReportEndDate DATETIME,
    @MMSClubIDList VARCHAR(4000)
)

AS
BEGIN 
SET XACT_ABORT ON
SET NOCOUNT ON

DECLARE @ReportRunDate_FirstOfPriorMonth DATETIME
SET @ReportRunDate_FirstOfPriorMonth = (Select CalendarPriorMonthStartingDate
                                        From vReportDimDate
                                        Where vReportDimDate.CalendarDate = Convert(Datetime,Convert(Varchar,(DATEPART(MM,GETDATE())))+'-'+CONVERT(Varchar,DATEPART(DAY,GETDATE()))+'-'+Convert(Varchar,DATEPART(Year,GETDATE()))))

---- Since we are using replicated data, we do not have historical jr. dues prices, so unless a recent period is selected, no Jr. dues will be returned.
DECLARE @CalculateJuniorDues VARCHAR(1)
SET @CalculateJuniorDues = (CASE WHEN @DateFilter = 'Non-Terminated Memberships As of Date'AND @ReportStartDate >=@ReportRunDate_FirstOfPriorMonth
                                  THEN 'Y'
                                WHEN @DateFilter <> 'Non-Terminated Memberships As of Date'AND @ReportEndDate >=@ReportRunDate_FirstOfPriorMonth
                                  THEN 'Y'
                                  ELSE 'N'
                                END)
                               
DECLARE @ReportRunDate VARCHAR(21)
SET @ReportRunDate = Substring(convert(varchar,GetDate(),100),1,6)+', '+ Convert(Varchar,DATEPART(year,GetDate()))

SELECT DISTINCT item MMSClubID
  INTO #MMSClubIDList
  FROM fnParsePipeList(@MMSClubIDList)

Select MPT.MembershipID,PT.ProductID, C.ClubID,
             Sum(PTP.Price)As MembershipJrDues,@ReportRunDate as ReportRunDate
             
               From vMembershipProductTier  MPT
               Join vProductTier PT
                On MPT.ProductTierID = PT.ProductTierID
               Join vMembership MS
               On MPT.MembershipID = MS.MembershipID
               Join vClub C
                On MS.ClubID = C.ClubID
               Join #MMSClubIDList #C
                 On Convert(Varchar,C.ClubID) = #C.MMSClubID    ------ Conversion forced due to Cognos Framework Manager error
               Join vMembershipType MT
                On MS.MembershipTypeID = MT.MembershipTypeID
               Join vProductTierPrice PTP
                On PT.ProductTierID = PTP.ProductTierID
               Join vValMembershipTypeGroup VMTG
                On PTP.ValMembershipTypeGroupID = VMTG.ValMembershipTypeGroupID
                AND MT.ValMembershipTypeGroupID = VMTG.ValMembershipTypeGroupID
               Join vMember M
                On M.MembershipID = MS.MembershipID
             Where @CalculateJuniorDues = 'Y'
               AND M.ValMemberTypeID = 4
               AND M.ActiveFlag = 1
               AND PT.ValProductTierTypeID = 1
               And (M.AssessJrMemberDuesFlag = 1 or M.AssessJrMemberDuesFlag is null )
               AND (C.AssessJrMemberDuesFlag = 1 or C.AssessJrMemberDuesFlag is null )
               AND (MT.AssessJrMemberDuesFlag = 1 or MT.AssessJrMemberDuesFlag is null )
             Group by MPT.MembershipID,PT.ProductID, C.ClubID
             Order by MPT.MembershipID
     
Drop Table #MMSClubIDList


END

