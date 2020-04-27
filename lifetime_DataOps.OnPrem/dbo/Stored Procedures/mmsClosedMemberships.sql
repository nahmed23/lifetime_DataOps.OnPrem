



--THIS PROCEDURE RETUNRS THE DETAILS OF MEMBERSHIP SOLD
--FOR MONTH TO DAY TILL YESTERDAY FOR A GIVEN CLUB(S).
-- WILL TAKE LIST OF CLUBS(SEPERATED BY COMMA) AS INPUT.


CREATE PROCEDURE mmsClosedMemberships
  @ClubIDList VARCHAR(1000)
AS
BEGIN

  SET XACT_ABORT ON
  SET NOCOUNT ON
    DECLARE @Yesterday DATETIME
    DECLARE @FirstOfMonth DATETIME
    
    -- Parse the ClubIDs into a temp table
    CREATE TABLE #ClubID(ClubID INT)
    EXEC procParseClubIDs @ClubIDList

    SET @Yesterday = DATEADD(dd, -1, CONVERT(DATETIME, CONVERT(VARCHAR, GETDATE(), 102), 102))
    SET @FirstOfMonth = CONVERT(DATETIME, SUBSTRING(CONVERT(VARCHAR,@yesterday,112),1,6) + '01', 112)

    SELECT C.ClubID,C.ClubName, M.MemberID, M.FirstName, M.LastName, M.JoinDate, 
           MS.CreatedDateTime, P.Description MembershipTypeDescription,
           E.FirstName AdvisorFirstName,E.LastName AdvisorLastName,
           MTFS.Description MembershipSizeDescription,@Yesterday ReportDate,
           MS.CompanyID
    FROM dbo.vClub C JOIN dbo.vMembership MS ON C.ClubID=MS.ClubID
                       JOIN dbo.vMember M ON MS.MembershipID=M.MembershipID
                       JOIN dbo.vMembershipType MT ON MS.MembershipTypeID=MT.MembershipTypeID
                       JOIN dbo.vProduct P ON MT.ProductID=P.ProductID
                       JOIN dbo.vEmployee E ON MS.AdvisorEmployeeID=E.EmployeeID
                       JOIN dbo.vValMembershipTypeFamilyStatus MTFS ON MTFS.ValMembershipTypeFamilyStatusID=MT.ValMembershipTypeFamilyStatusID
                       JOIN #ClubID CI ON C.ClubID = CI.ClubID
    WHERE M.ValMemberTypeID=1 AND
          M.JoinDate>=@FirstOfMonth AND
          M.JoinDate<=@Yesterday AND
          P.Description NOT LIKE '%Employee%' AND 
          P.Description NOT LIKE '%Short%'


END





