







-- looking at terminations cancelled for non payment
-- checking for last visit to club
-- parameters: startdate, endate

CREATE PROC dbo.mmsNPTAnalysis(
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

SELECT C.ClubName, MS.MembershipID, MS.ExpirationDate,
       M.MemberID AS PrimaryMemberID, 
       M.FirstName AS PrimaryFirstName, 
       M.LastName AS PrimaryLastName,
       VMTFS.Description AS MembershipSizeDescription,
       (SELECT MAX(MU.UsageDateTime) 
          FROM dbo.vMemberUsage MU
          JOIN dbo.vMember M2
               ON MU.MemberID = M2.MemberID
         WHERE M2.MembershipID = MS.MembershipID
       ) AS LastUsageDateTime
  FROM dbo.vClub C
  JOIN dbo.vMembership MS
       ON C.ClubID = MS.ClubID
  JOIN dbo.vValTerminationReason VTR
       ON VTR.ValTerminationReasonID = MS.ValTerminationReasonID
  JOIN dbo.vMember M
       ON MS.MembershipID = M.MembershipID
  JOIN dbo.vMembershipType MST
       ON MS.MembershipTypeID = MST.MembershipTypeID
  JOIN dbo.vValMembershipTypeFamilyStatus VMTFS 
       ON MST.ValMembershipTypeFamilyStatusID = VMTFS.ValMembershipTypeFamilyStatusID
 WHERE VTR.Description = 'Non-Payment Terms' AND
       MS.ExpirationDate BETWEEN @StartDate AND @EndDate AND
       M.ValMemberTypeID = 1

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END















