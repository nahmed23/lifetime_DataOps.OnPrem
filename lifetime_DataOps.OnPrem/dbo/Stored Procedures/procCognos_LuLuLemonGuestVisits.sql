 
CREATE PROC [dbo].[procCognos_LuLuLemonGuestVisits] (
    @StartDate DATETIME,
    @EndDate DATETIME
    
)

AS
BEGIN 
SET XACT_ABORT ON
SET NOCOUNT ON
	
		
Select		
 PP_LuLuVisits.ClubID		
, PP_ClubVisits.ClubCode		
, PP_LuLuGuestType.Description		
 		
, Guest.MaskedPersonalID		
, PP_LuLuVisits.GuestID		
, PP_LuLuVisits.GuestVisitID		
	
, PP_LuLuVisits.VisitDateTime as VisitDate		
, PP_LuLuVisits.EmployeeID		as VisitCreatedBy
,PP_LuLuVisits.Comment as EmployeeComments	
		
		
		
		
From vGuestVisit PP_LuLuVisits		
	Inner Join vGuest Guest	
		On PP_LuLuVisits.GuestID= Guest.GuestID
	Inner Join vClub PP_ClubVisits	
on PP_LuLuVisits.ClubId= PP_ClubVisits.clubID		
	Inner Join vValGuestAccessMethod PP_LuLuGuestType	
    On PP_LuLuVisits.ValGuestAccessMethodID= PP_LuLuGuestType.ValGuestAccessMethodID		
Where PP_LuLuVisits.VisitDateTime Between @StartDate and @EndDate and PP_LuLuGuestType.valGuestAccessMethodID=8 		
order by PP_ClubVisits.ClubCode ASC, PP_LuLuVisits.GuestID, PP_LuLuVisits.VisitDateTime		


END
