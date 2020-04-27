





--THIS PROCEDURE RETUNRS THE DETAILS OF MEMBERSHIPS SOLD BY EACH MEMBERSHIPADVISOR 
--TILL YESTERDAY. WILL TAKE LIST OF CLUBS(SEPERATED BY COMMA) AS INPUT.

CREATE  PROCEDURE dbo.mmsMATotalMemberships
  @ClubIDList VARCHAR(1000)
AS
BEGIN

  SET XACT_ABORT ON
  SET NOCOUNT ON
    DECLARE @Yesterday DATETIME

    -- Parse the ClubIDs into a temp table
    CREATE TABLE #ClubID(ClubID INT)
    EXEC procParseClubIDs @ClubIDList

    SET @Yesterday = DATEADD(dd, -1, CONVERT(DATETIME, CONVERT(VARCHAR, GETDATE(), 102), 102))

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

    SELECT COUNT (DISTINCT (MS.MembershipID)) MembershipCount,
           E.FirstName  AdvisorFirstName,
           E.LastName AdvisorLastName,C.ClubID,
           C.ClubName,@Yesterday ReportDate,
           C.DomainNamePrefix
    FROM dbo.vValMembershipStatus VMS 
                JOIN dbo.vMembership MS ON VMS.ValMembershipStatusID=MS.ValMembershipStatusID
                JOIN dbo.vMember M ON M.MembershipID = MS.MembershipID AND M.ValMemberTypeID = 1
                JOIN dbo.vClub C ON MS.ClubID = C.ClubID
                JOIN #ClubID CI ON C.ClubID = CI.ClubID
                LEFT OUTER JOIN dbo.vEmployee E ON MS.AdvisorEmployeeID=E.EmployeeID
    WHERE VMS.ValMembershipStatusID IN (2,3,4,5,6,7)
          AND ISNULL(M.JoinDate,'JAN 01 2000') <= @Yesterday
    GROUP BY E.FirstName, E.LastName, C.ClubName,C.ClubID,C.DomainNamePrefix

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END








