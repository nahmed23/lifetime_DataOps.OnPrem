



--
-- returns deliquent accounts per club within specified parameters 
--
-- Parameters: A | separated list MemberIDs
--

CREATE        PROC dbo.mmsDelinquentstmt_StatementMessage (
  @MemberIDList VARCHAR(8000),
  @ClubIDList VARCHAR(2000),
  @CancellationRequestDate SMALLDATETIME
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

CREATE TABLE #tmpList (StringField VARCHAR(15))
CREATE TABLE #MemberIDs (MemberID INT)
if @MemberIDList = 'NPT' 
begin
  CREATE TABLE #Clubs (ClubID VARCHAR(15))
  EXEC procParseStringList @ClubIDList
  INSERT INTO #Clubs (ClubID) SELECT StringField FROM #tmpList
  TRUNCATE TABLE #tmpList
INSERT INTO #MemberIDs (MemberID)

SELECT M.MemberID
  FROM dbo.vMembership MS
  JOIN dbo.vMember M
       ON M.MembershipID = MS.MembershipID
  JOIN dbo.vClub C
       ON MS.ClubID = C.ClubID
  JOIN #Clubs CS
       ON C.ClubID = CS.ClubID
  JOIN dbo.vValMembershipStatus VMS
       ON MS.ValMembershipStatusID = VMS.ValMembershipStatusID
  JOIN dbo.vValTerminationReason VTR 
       ON MS.ValTerminationReasonID = VTR.ValTerminationReasonID
 WHERE MS.CancellationRequestDate = @CancellationRequestDate AND
       M.ValMemberTypeID = 1 AND
       VMS.Description = 'Pending Termination' AND
       VTR.Description = 'Non-Payment Terms' AND
       C.DisplayUIFlag = 1

DROP TABLE #Clubs

END

ELSE

BEGIN
  EXEC procParseStringList @MemberIDList
  INSERT INTO #MemberIDs (MemberID) SELECT StringField FROM #tmpList
  TRUNCATE TABLE #tmpList
end 

SELECT MS.MembershipID, VEFTO.ValEFTOptionID, VEFTO.Description EFTOptionDescription,
       VPT.Description EFTPmtMethodDescription, VR.Description RegionDescription, C.ClubName,
       SA.FirstName, SA.LastName, SA.AddressLine1,
       SA.AddressLine2, SA.City, SA.Zip,
       SA.CompanyName, M2.MemberID PrimaryMemberID, M.MemberID UISelectedMemberID,
       VS.Abbreviation StateAbbreviation, VC.Abbreviation CountryAbbreviation,
       CA.AddressLine1 AS ClubAddress1, CA.AddressLine2 AS ClubAddress2,
       CA.City AS ClubCity, CA.Zip AS ClubZip, CVS.Abbreviation AS ClubState
  FROM dbo.vClub C
  JOIN dbo.vMembership MS
       ON C.ClubID = MS.ClubID
  JOIN dbo.vMember M2
       ON MS.MembershipID = M2.MembershipID
  JOIN dbo.vValRegion VR
       ON C.ValRegionID = VR.ValRegionID
  JOIN dbo.vStatementAddress SA
       ON MS.MembershipID = SA.MembershipID
  JOIN dbo.vValMemberType VMT
       ON M2.ValMemberTypeID = VMT.ValMemberTypeID
  JOIN dbo.vValMembershipStatus VMS
       ON MS.ValMembershipStatusID = VMS.ValMembershipStatusID
  JOIN dbo.vTranBalance TB
       ON TB.MembershipID = MS.MembershipID
  JOIN dbo.vMember M
       ON M.MembershipID = MS.MembershipID
  JOIN #MemberIDs MI 
       ON M.MemberID = MI.MemberID
  JOIN dbo.vMembershipBalance MB
       ON MS.MembershipID = MB.MembershipID
  JOIN dbo.vValCountry VC
       ON VC.ValCountryID = SA.ValCountryID
  JOIN dbo.vValState VS
       ON VS.ValStateID = SA.ValStateID
  JOIN dbo.vClubAddress  CA
       ON CA.ClubID = C.ClubID
  JOIN dbo.vValState CVS
       ON CA.ValStateID = CVS.ValStateID
  LEFT JOIN dbo.vValEFTOption VEFTO
       ON MS.ValEFTOptionID = VEFTO.ValEFTOptionID
  LEFT JOIN dbo.vEFTAccountDetail EFTD
       ON MS.MembershipID = EFTD.MembershipID
  LEFT JOIN dbo.vValPaymentType VPT
       ON EFTD.ValPaymentTypeID = VPT.ValPaymentTypeID 
 WHERE VMT.Description = 'Primary' AND
       TB.TranBalanceAmount > 0 AND
       MB.CommittedBalance > 0 
Group By MS.MembershipID, VEFTO.ValEFTOptionID, VEFTO.Description,
       VPT.Description, VR.Description, C.ClubName,
       SA.FirstName, SA.LastName, SA.AddressLine1,
       SA.AddressLine2, SA.City, SA.Zip,
       SA.CompanyName, M2.MemberID, M.MemberID,
       VS.Abbreviation, VC.Abbreviation,
       CA.AddressLine1, CA.AddressLine2,
       CA.City, CA.Zip, CVS.Abbreviation

DROP TABLE #MemberIDs
DROP TABLE #tmpList

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END




