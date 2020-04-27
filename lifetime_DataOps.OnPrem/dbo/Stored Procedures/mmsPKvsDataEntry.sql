




--
-- Returns recordset for PKvsDataEntry
--
-- Parameters: A start and end create date
--

CREATE PROC dbo.mmsPKvsDataEntry (
  @StartDate SMALLDATETIME,
  @EndDate SMALLDATETIME
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

SELECT MS.MembershipID, C.ClubName, MS.CreatedDateTime,
       M.MemberID PrimaryMemberID, VMSS.Description SourceDescription, 
       E.EmployeeID AdvisorEmployeeID, E.FirstName AdvisorFirstname, E.LastName AdvisorLastname
  FROM dbo.vClub C
  JOIN dbo.vMembership MS
       ON MS.ClubID = C.ClubID
  JOIN dbo.vMember M
       ON M.MembershipID = MS.MembershipID
  JOIN dbo.vValMembershipSource VMSS
       ON MS.ValMembershipSourceID = VMSS.ValMembershipSourceID
  JOIN dbo.vEmployee E 
       ON MS.AdvisorEmployeeID = E.EmployeeID
 WHERE MS.CreatedDateTime BETWEEN @StartDate AND @EndDate AND
       M.ValMemberTypeID = 1

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END





