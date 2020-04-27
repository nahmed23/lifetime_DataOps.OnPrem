








--
-- Returns Member and Membership ids for a list of memberships
--
-- parameters: a | separated list of membershipids (int)
--

CREATE    PROC dbo.mmsPosdrawer_NewPKMembers (
  @MembershipList VARCHAR(1000)
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

  CREATE TABLE #tmpList (StringField VARCHAR(50))

  EXEC procParseStringList @MembershipList
  CREATE TABLE #Membership (MembershipID INT)
  INSERT INTO #Membership (MembershipID) SELECT StringField FROM #tmpList

  SELECT MS.MembershipID, M.MemberID MembershipsMemberids, PM.MemberID PrimaryMemberid, 
         UPPER(PM.FirstName) PrimaryFirstname, UPPER(PM.LastName) PrimaryLastname,
         VET.Description EnrollmentTypeDescription
    FROM dbo.vMembership MS
    JOIN #Membership MSP
         ON MS.MembershipID = MSP.MembershipID
    JOIN dbo.vMember M
         ON MS.MembershipID = M.MembershipID
    JOIN dbo.vMember PM 
         ON MS.MembershipID = PM.MembershipID
    JOIN dbo.vValEnrollmentType VET
         ON MS.ValEnrollmentTypeID = VET.ValEnrollmentTypeID
   WHERE PM.ValMemberTypeID = 1

  DROP TABLE #Membership
  DROP TABLE #tmpList

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity
 
END







