
CREATE PROC [dbo].[procCognos_LTHealthCoachingCalls] (      
    @StartDate DATETIME,
    @EndDate DATETIME
)

AS
BEGIN 
SET XACT_ABORT ON 
SET NOCOUNT ON

--DECLARE @Startdate DATETIME = '1/1/1900'
--DECLARE @EndDate DATETIME = '12/31/2017'

SET @StartDate = CASE WHEN @StartDate = '1/1/1900' THEN GETDATE()	--Today
					  ELSE @StartDate END
SET @EndDate = CASE WHEN @EndDate = '1/1/1900' THEN GETDATE()+4
					ELSE @EndDate END


Select
  RTRIM(p.player_name)  MemberName
, p.mbr_code as MemberID
, 0 as CallsAvailable
, MIN(r.start_date)  NextCallDate
, ri.name  CoachName
, COUNT(r.start_date) as CallsScheduled

INTO #ReservationData
FROM
BOSS..asireserv r  
JOIN BOSS..asiplayer p
  ON r.reservation = p.reservation
JOIN Report_MMS..vMembership MS
  ON MS.MembershipID = p.cust_code
LEFT JOIN BOSS..asiresinst ri
  ON ri.reservation = r.reservation


Where 
 r.upccode = '701592962591' --Coaching Call
AND (CAST(r.start_date as DATE) BETWEEN @StartDate AND @EndDate OR r.start_date IS NULL)
AND MS.CompanyID != 20429   --U.S. Bank - Total Health

GROUP BY p.player_name, ri.name, p.mbr_code 

--ORDER BY MIN(r.start_date) desc, p.player_name

----------------------Calls Available----------------------------------
UNION

Select
  RTRIM(M.LastName) + ', ' + M.FirstName MemberName
, M.MemberID  MemberID
, Package.SessionsLeft  CallsAvailable
, Null
, Null
, 0


FROM
  Report_MMS..vPackage Package
JOIN Report_MMS..vMember M
  ON M.MemberID = Package.MemberID
JOIN Report_MMS..vMembership MS
  ON MS.MembershipID = M.MembershipID 
JOIN Report_MMS..vMembershipType MST
  ON MS.MembershipTypeID = MST.MembershipTypeID

Where 
 Package.ProductID = '5225'   
AND Package.SessionsLeft > 0
AND MS.CompanyID != 20429   --U.S. Bank - Total Health

GROUP BY
  RTRIM(M.LastName) + ', ' + M.FirstName
, M.MemberID
, Package.SessionsLeft



SELECT RD.MemberName
, RD.MemberID
, SUM(RD.CallsAvailable) as CallsAvailable
, SUM(RD.CallsScheduled) as CallsScheduled
, MIN(CAST(RD.NextCalldate as DATETIME)) as NextCalldate
, MIN(RD.CoachName) as CoachName
, SUM(RD.CallsAvailable) - SUM(RD.CallsScheduled) as AvailableVsScheduled

FROM #ReservationData RD
WHERE RD.MemberName != 'Guest, Guest'
GROUP BY RD.MemberName
, RD.MemberID

  ORDER BY RD.MemberName

DROP TABLE #ReservationData


--SELECT * FROM Sandbox_INT.rep.CCallTestdata
END
