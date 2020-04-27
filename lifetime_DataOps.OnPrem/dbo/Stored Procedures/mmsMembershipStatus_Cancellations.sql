

--
-- returns memberships cancelled in the last month
--

CREATE PROC dbo.mmsMembershipStatus_Cancellations
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

  SELECT MS.MembershipID, MS.CancellationRequestDate MembershipCancellationrequestdate, 
         VR.Description RegionDescription,
         C.ClubName, VTR.Description TerminationReasonDescription, 
         VTR.ValTerminationReasonID,
         MS.ExpirationDate, GETDATE() ReportDate
    FROM dbo.vCLUB C
    JOIN dbo.vValRegion VR
         ON C.ValRegionID = VR.ValRegionID
    JOIN dbo.vMembership MS
         ON C.ClubID = MS.ClubID
    LEFT JOIN dbo.vValTerminationReason VTR
         ON VTR.ValTerminationReasonID = MS.ValTerminationReasonID 
   WHERE MS.CancellationRequestDate >= DATEADD(day,-32,GETDATE())

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END


