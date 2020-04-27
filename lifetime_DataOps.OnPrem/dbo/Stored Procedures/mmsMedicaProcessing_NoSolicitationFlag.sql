





--
-- returns no-solicitation information for the Medica Processing Brio document
--
-- Parameters: Expiration date
--

CREATE PROC dbo.mmsMedicaProcessing_NoSolicitationFlag (
  @ExpirationDate SMALLDATETIME
)

AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

SELECT M.MemberID, MS.MembershipID, CP.Description FlagDescription,
       CP.ValCommunicationPreferenceID
  FROM dbo.vMembership MS
  JOIN dbo.vMembershipCommunicationPreference MCP
    ON MS.MembershipID = MCP.MembershipID
  JOIN dbo.vValCommunicationPreference CP
    ON MCP.ValCommunicationPreferenceID = CP.ValCommunicationPreferenceID
  JOIN dbo.vMember M
    ON M.MembershipID = MS.MembershipID
  JOIN dbo.vValMemberType MT
    ON M.ValMemberTypeID = MT.ValMemberTypeID
 WHERE M.CWMedicaNumber > '0' AND 
       MCP.ActiveFlag = 1 AND 
       (MS.ExpirationDate > @ExpirationDate OR 
       MS.ExpirationDate IS NULL) AND 
       MT.Description IN ('Partner', 'Primary', 'Secondary')

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END






