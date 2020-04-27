


--	dbo.mmsClubList
--	This stored procedure is designed to supply Club Name values
--	report.  
--	
--	Exec mmsClubList 

CREATE			PROC dbo.mmsClubList 

AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

SELECT 
ClubID, ClubName

FROM	vClub 

END



