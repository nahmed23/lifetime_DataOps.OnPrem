

CREATE PROC [dbo].[procCognos_LuLuLemonVisits] (
    @StartDate DATETIME,
    @EndDate DATETIME
    
)

AS
BEGIN 
SET XACT_ABORT ON
SET NOCOUNT ON
	
		
Select					
					
 [Area]=A.Description					
 ,[Club]=Club.ClubCode					
					
					
,[PromotionalPass]=Case					
					When PP_LuLuTotalGuestVisits IS NULL
					Then 0
					Else PP_LuLuTotalGuestVisits
					End
					
					
From vClub Club					
Inner Join vValSalesArea A					
On A.ValSalesAreaID=Club.ValSalesAreaID					
					
					
--Get the LuLuober Promotional Pass visits + Lululemon 1 Day Pass + WCY Orange Trial Membership					
Inner Join					
(Select					
 [PP_LuLuVisitsClubID]= PP_LuLuVisits.ClubID					
,Count(PP_LuLuVisits.GuestID) as PP_LuLuTotalGuestVisits 					
From vGuestVisit PP_LuLuVisits					
	Inner Join vClub PP_ClubVisits				
on PP_LuLuVisits.ClubId= PP_ClubVisits.clubID					
	Inner Join vValGuestAccessMethod PP_LuLuGuestType				
    On PP_LuLuVisits.ValGuestAccessMethodID= PP_LuLuGuestType.ValGuestAccessMethodID					
Where PP_LuLuVisits.VisitDateTime Between @StartDate and @EndDate and PP_LuLuGuestType.valGuestAccessMethodID=8 					
Group BY PP_LuLuVisits.ClubID					
      )PromotionalPassTotalLuLuGuestVisits					
On Club.ClubId= PP_LuLuVisitsClubID		



END
