




CREATE PROCEDURE dbo.mmsPendingTerminationMembersToSiebel
AS

BEGIN

  SET XACT_ABORT ON
  SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

  SELECT M.MemberID,M.FirstName,M.LastName,C.DomainNamePrefix,valmembershipstatusid,cancellationrequestdate
  FROM vMembership MS JOIN vMember M ON MS.MembershipID = M.MembershipID
                      JOIN vClub C ON MS.CluBID = C.ClubID
  WHERE M.ValMemberTypeID = 1 AND ValMembershipStatusID IN(2)
  AND MS.CancellationRequestDate > DATEADD(D,-3, CAST(CONVERT(VARCHAR,GETDATE(),101) AS DATETIME))
  AND MS.ClubID NOT IN (8,151)

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END




