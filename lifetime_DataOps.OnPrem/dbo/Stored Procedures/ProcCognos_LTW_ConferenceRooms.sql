
CREATE PROC [dbo].[ProcCognos_LTW_ConferenceRooms] (      
    @StartDate DATETIME,
    @EndDate DATETIME,
	@Club INT
)
AS
BEGIN 
SET XACT_ABORT ON
SET NOCOUNT ON

--DECLARE 
--@StartDate Datetime,
--@EndDate DATETIME,
--@Club INT

--SET @StartDate = '5/1/2019'
--SET @EndDate = '5/30/2019'
--SET @Club = 262


 -------BOSS Conference Room Reservations
Select 
 club.ClubName
, M.MembershipID
, M.MemberID
, M.FirstName
, M.LastName
, Co.CompanyName
, r.upc_desc
, r.resource
, SUM(r.def_price) as Price
, @StartDate as StartDate
, @EndDate as EndDate
, p.mbr_code
, SUM(r.published_duration) Booked

 

From BOSS..asireserv r
  JOIN BOSS..asiplayer p
    ON r.reservation = p.reservation
  JOIN boss..asiinvtr i
    on i.invtr_upccode = r.upccode
  JOIN Report_MMS..vMember M
    ON M.MemberID = P.mbr_code
  JOIN Report_MMS..vMembership MS
    ON MS.MembershipID = M.MembershipID
  JOIN Report_MMS..vclub club
    ON club.clubid = r.Club
  LEFT JOIN Report_MMS..vCompany CO
    ON MS.CompanyID = CO.CompanyID

WHERE i.invtr_sku = 'LIFE TIME WORK    '

  AND CAST(r.start_date as DATE) BETWEEN @StartDate AND @EndDate
  AND r.club IN (@Club)

GROUP BY p.mbr_code,
 club.ClubName
, M.MembershipID
, M.MemberID
, M.FirstName
, M.LastName
, Co.CompanyName
, r.upc_desc
, r.resource

Order by ClubName, FirstName, LastName, resource


END

