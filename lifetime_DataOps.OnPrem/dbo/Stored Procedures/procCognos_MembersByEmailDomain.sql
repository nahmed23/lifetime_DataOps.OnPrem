
CREATE PROC [dbo].[procCognos_MembersByEmailDomain] (
@ClubIDList VARCHAR(2000)
, @EmailDomain VARCHAR(255))

AS
BEGIN 

SET XACT_ABORT ON
SET NOCOUNT ON

SELECT DISTINCT Club.ClubID 
INTO #Clubs
FROM vClub Club
  JOIN fnParsePipeList(@ClubIDList) MMSClubIDList
    ON Convert(Varchar,Club.ClubID) = MMSClubIDList.Item
    OR @ClubIDList like '%All Clubs%'

SELECT Count (Distinct M.MemberID) AS MemberEmailDomainCount
from vMember M
join vmembership ms 
     on M.membershipID = ms.membershipID
  JOIN #Clubs tC
       ON ms.ClubID = tC.ClubID
where M.emailaddress like '%'+@EmailDomain
and M.ActiveFlag = '1'

DROP TABLE #Clubs

END
