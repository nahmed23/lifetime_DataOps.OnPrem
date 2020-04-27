




CREATE PROCEDURE dbo.mmsTerminatedMembersToSiebel 
AS

BEGIN

  SET XACT_ABORT ON
  SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

  SELECT M.MemberID,M.FirstName,M.LastName,C.DomainNamePrefix
  FROM vMembership MS JOIN vMember M ON MS.MembershipID = M.MembershipID
                      JOIN vClub C ON MS.CluBID = C.ClubID
  WHERE M.ValMemberTypeID = 1 AND ValMembershipStatusID IN(1,3)
  AND MS.ExpirationDate > DATEADD(D,-3, CAST(CONVERT(VARCHAR,GETDATE(),101) AS DATETIME))
  AND MS.ClubID NOT IN (8,151)


-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END




