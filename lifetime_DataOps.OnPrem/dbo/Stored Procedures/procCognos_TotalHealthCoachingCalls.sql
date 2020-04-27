
CREATE PROC [dbo].[procCognos_TotalHealthCoachingCalls]   
(
                 @CompanyIDList VARCHAR(2000))
--Exec procCognos_TotalHealthCoachingCalls '18848|17226|18292|16830|17305|20454|18347'

AS
BEGIN 
SET XACT_ABORT ON
SET NOCOUNT ON

DECLARE @ReportRunDateTime VARCHAR(21)  
SET @ReportRunDateTime = Replace(Substring(convert(varchar,getdate(),100),1,6)+', '+Substring(convert(varchar,GETDATE(),100),8,10)+' '+Substring(convert(varchar,getdate(),100),18,2),'  ',' ')
CREATE TABLE #tmpList (StringField VARCHAR(50))
CREATE TABLE #CompanyIDList (CompanyID VARCHAR(50))

EXEC procParseStringList @CompanyIDList
INSERT INTO #CompanyIDList (CompanyID) 
	SELECT StringField FROM #tmpList

SELECT DISTINCT
       Member.Party_id,
       Member.MemberID,
	   Player.mbr_code,
       Reservation.resource Advisor_name, 
       Reservation.start_date Start_datetime, 
	   Reservation.reservation,
	   Reservation.resource,
	   Reservation.upccode,
	   Reservation.start_date,
       Company.CompanyName, 
	   Company.CorporateCode,
	   Company.CompanyID,
       Member.FirstName, 
       Member.LastName, 
       MemberPhoneNumbers.HomePhoneNumber, 
       Member.EmailAddress,
	   Member.JoinDate,
	   @ReportRunDateTime ReportRunDateTime

FROM BOSS..asiplayer Player
JOIN BOSS..asireserv Reservation 
  ON Player.Reservation = Reservation.Reservation
JOIN Report_MMS..vMember Member 
  ON Player.mbr_code = Member.Memberid
JOIN Report_MMS..vMembership Membership 
  ON Member.MembershipID = Membership.MembershipID
JOIN Report_MMS..vCompany Company 
  ON Membership.CompanyID = Company.CompanyID
LEFT JOIN Report_MMS..vMemberPhoneNumbers MemberPhoneNumbers 
  ON Membership.MembershipID = MemberPhoneNumbers.MembershipID
JOIN #CompanyIDList CIL 
  ON CIL.CompanyID = Company.CompanyID

WHERE Reservation.upccode IN ('701592733355','701592798701')
--AND Company.CorporateCode = '84549'  --WoundedWarrior
AND Reservation.start_date >= CONVERT(DATE,GETDATE(), 112)
ORDER BY Reservation.resource, Reservation.start_date


END
