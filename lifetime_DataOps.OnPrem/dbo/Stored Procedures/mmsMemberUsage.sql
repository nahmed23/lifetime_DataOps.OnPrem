






--THIS PROCEDURE RETURNS THE MEMBER USAGE STATISTICS FOR A GIVEN MEMBER
--AND A GIVEN DATE RANGE.

CREATE  PROCEDURE dbo.mmsMemberUsage
  @InputMemberID    INT,
  @InputStartDate   DATETIME,
  @InputEndDate     DATETIME

AS
BEGIN

  SET XACT_ABORT ON
  SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

  SELECT C.ClubName, 
         MU.UsageDateTime,
         VMT.Description MemberTypeDescription,
         M.MemberID,
         M.FirstName,
         M.LastName
  FROM dbo.vClub C
       JOIN vMemberUsage MU ON C.ClubID = MU.ClubID
       JOIN vMember M ON MU.MemberID = M.MemberID
       JOIN vValMemberType VMT ON M.ValMemberTypeID = VMT.ValMemberTypeID
       JOIN vMembership MS ON M.MembershipID = MS.MembershipID
  WHERE M.MemberID = @InputMemberID AND 
        MU.UsageDateTime > @InputStartDate AND 
        MU.UsageDateTime < @InputEndDate

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity


END






