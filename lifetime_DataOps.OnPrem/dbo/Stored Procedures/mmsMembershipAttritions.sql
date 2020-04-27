




--THIS PROCEDURE RETUNRS THE DETAILS OF MEMBERSHIP ATTRITIONS 
--IN THE CURRENT MONTH FOR A GIVEN CLUB(S).
-- WILL TAKE LIST OF CLUBS(SEPERATED BY COMMA) AS INPUT.

CREATE PROCEDURE mmsMembershipAttritions
  @ClubIDList VARCHAR(1000)
AS
BEGIN

  SET XACT_ABORT ON
  SET NOCOUNT ON
    DECLARE @Yesterday DATETIME
    DECLARE @FirstOfMonth DATETIME
    DECLARE @FirstOfNextMonth DATETIME

    -- Parse the ClubIDs into a temp table
    CREATE TABLE #ClubID(ClubID INT)
    EXEC procParseClubIDs @ClubIDList

    SET @Yesterday = DATEADD(dd, -1, CONVERT(DATETIME, CONVERT(VARCHAR, GETDATE(), 102), 102))
    SET @FirstOfMonth = CONVERT(DATETIME, SUBSTRING(CONVERT(VARCHAR,@yesterday,112),1,6) + '01', 112)
    SET @FirstOfNextMonth = DATEADD(mm, 1,@FirstOfMonth)

    SELECT C.ClubID,C.ClubName,M.MemberID PrimaryMemberID ,M.FirstName PrimaryFirstName,
           M.LastName PrimaryLastName,MS.ExpirationDate, VTR.Description TermReasonDescription,
           E.FirstName AdvisorFirstName,E.LastName AdvisorLastName,P.Description MembershipTypeDescription,
           M.JoinDate, @Yesterday ReportDate
    FROM dbo.vClub C JOIN dbo.vMembership MS ON C.ClubID=MS.ClubID
                     JOIN dbo.vMember M ON M.MembershipID=MS.MembershipID
                     JOIN dbo.vValTerminationReason VTR ON VTR.ValTerminationReasonID=MS.ValTerminationReasonID
                     JOIN dbo.vEmployee E ON MS.AdvisorEmployeeID=E.EmployeeID 
                     JOIN dbo.vMembershipType MT ON MS.MembershipTypeID=MT.MembershipTypeID 
                     JOIN dbo.vProduct P ON MT.ProductID=P.ProductID
                     JOIN #ClubID CI ON C.ClubID = CI.ClubID
    WHERE M.ValMemberTypeID=1 AND 
          MS.ExpirationDate>=@FirstOfMonth AND  
          MS.ExpirationDate < @FirstOfNextMonth AND
          P.Description NOT LIKE '%Employee%' AND 
          P.Description NOT LIKE '%Short%'

END






