












--THIS PROCEDURE RETUNRS THE DETAILS OF Sports Non Access memberships sale attritions 
--FOR MONTH TO DAY Yesterday FOR A GIVEN CLUB(S).
-- WILL TAKE LIST OF CLUBS(SEPERATED BY COMMA) AS INPUT.

CREATE    PROCEDURE dbo.mmsDSSR_SportsNonAccess
  @ClubIDList VARCHAR(1000)
AS
BEGIN

  SET XACT_ABORT ON
  SET NOCOUNT ON

    DECLARE @Yesterday DATETIME
    DECLARE @FirstOfMonth DATETIME

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

    -- Parse the ClubIDs into a temp table
    CREATE TABLE #ClubID(ClubID INT)
    EXEC procParseClubIDs @ClubIDList

    SET @Yesterday = DATEADD(dd, -1, CONVERT(DATETIME, CONVERT(VARCHAR, GETDATE(), 102), 102))
    SET @FirstOfMonth = CONVERT(DATETIME, SUBSTRING(CONVERT(VARCHAR,@yesterday,112),1,6) + '01', 112)

    SELECT DSNA.MembershipID,DSNA.ActivationDate,DSNA.ExpirationDate,DSNA.CancellationRequestDate,
           DSNA.MemberID,DSNA.FirstName,DSNA.LastName,DSNA.ClubID, DSNA.ClubName,@Yesterday ReportDate,
           E.FirstName AS AdvisorFirstName, E.LastName AS AdvisorLastName,DSNA.Today_Flag,DSNA.TerminationDate,
           DSNA.SignOnDate
    FROM vDSSRSportsNonAccessSummary DSNA 
      JOIN #ClubID CI 
       ON DSNA.ClubID = CI.ClubID
      JOIN vMembership M
       ON DSNA.MembershipID = M.MembershipID
      JOIN vEmployee E
       ON M.AdvisorEmployeeID = E.EmployeeID
    -----WHERE DSNA.ActivationDate >= @FirstOfMonth
    ORDER BY DSNA.ClubName

DROP TABLE #ClubID

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END





