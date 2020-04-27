

--
-- Procedure returns monthly statements for members at Minneapolis Athletic club
-- currently no other clubs are planned to be like this, so the club is hardcoded
--

CREATE PROC dbo.mmsStatement_Message
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

  SELECT M.MembershipID, VEO.ValEFTOptionID, VEO.Description AS EFTOptionDescription,
         VPT.Description AS EFTPmtMethodDescription, MSB.PreviousStatementBalance, 
         MSB.PreviousStatementDateTime,
         C.ClubName, M.ValMembershipStatusID, MSB.StatementBalance
    FROM dbo.vClub C
    JOIN dbo.vMembership M
         ON C.ClubID = M.ClubID
    JOIN dbo.vMembershipBalance MSB
         ON M.MembershipID = MSB.MembershipID
    JOIN dbo.vValMembershipStatus VMSS
         ON M.ValMembershipStatusID = VMSS.ValMembershipStatusID
    LEFT JOIN dbo.vValEFTOption VEO
         ON (M.ValEFTOptionID = VEO.ValEFTOptionID)
    LEFT JOIN dbo.vEFTPaymentAccount EPA
         ON (M.MembershipID = EPA.MembershipID)
    LEFT JOIN dbo.vValPaymentType VPT
         ON (EPA.ValPaymentTypeID = VPT.ValPaymentTypeID)  
   WHERE C.ClubName = 'Minneapolis Athletic Club' AND
         VMSS.Description IN ('Active', 'Pending Termination', 'Suspended') AND
         C.ValStatementTypeID = 2

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END



