



--
-- returns deliquent accounts within specified parameters 
--
-- Parameters: clubid's
--

CREATE      PROC dbo.[OBSOLETE_mmsDeliquent_stmt_msg] (
  @ClubIDList VARCHAR(2000)
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

CREATE TABLE #tmpList (StringField VARCHAR(15))
CREATE TABLE #Clubs (ClubID VARCHAR(15))

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

IF @ClubIDList <> 'All'
BEGIN
--   INSERT INTO #Clubs EXEC procParseStringList @ClubList
   EXEC procParseStringList @ClubIDList
   INSERT INTO #Clubs (ClubID) SELECT StringField FROM #tmpList
   TRUNCATE TABLE #tmpList
END
ELSE
BEGIN
   INSERT INTO #Clubs VALUES('All') 
END
SELECT MS.MembershipID, VEO.ValEFTOptionID, VEO.Description AS EFTOptionDescription,
       VPT.Description AS EFTPmtMethodDescription, VR.Description AS RegionDescription, 
       C.ClubName, SA.FirstName, SA.LastName, SA.AddressLine1,
       SA.AddressLine2, SA.City, SA.Zip,
       SA.CompanyName, M.MemberID AS PrimaryMemberID, VTR.Description AS TerminationReasonDescription,
       VS.Abbreviation AS StateAbbreviation, VC.Abbreviation AS CountryAbbreviation,
       GETDATE() AS RunDate, CA.AddressLine1 AS ClubAddress1, CA.AddressLine2 AS ClubAddress2,
       CA.City AS ClubCity, CA.Zip AS ClubZip, CVS.Abbreviation AS ClubState
  FROM dbo.vClub C
  JOIN #Clubs CS
       ON C.ClubID = CS.ClubID OR CS.ClubID = 'All'
--  JOIN #Clubs CS
--       ON C.ClubName = CS.ClubName OR CS.ClubName = 'All'
  JOIN dbo.vMembership MS
       ON C.ClubID = MS.ClubID
  JOIN dbo.vValRegion VR
       ON C.ValRegionID = VR.ValRegionID
  JOIN dbo.vStatementAddress SA
       ON MS.MembershipID = SA.MembershipID
  JOIN dbo.vMember M
       ON MS.MembershipID = M.MembershipID
  JOIN dbo.vTranBalance TB
       ON TB.MembershipID = M.MembershipID
  JOIN dbo.vMembershipBalance MSB
       ON M.MembershipID = MSB.MembershipID
  JOIN dbo.vValCountry VC
       ON VC.ValCountryID = SA.ValCountryID
  JOIN dbo.vValState VS
       ON VS.ValStateID = SA.ValStateID
  JOIN dbo.vValMembershipStatus VMSS
       ON MS.ValMembershipStatusID = VMSS.ValMembershipStatusID
  JOIN dbo.vValMemberType VMT
       ON M.ValMemberTypeID = VMT.ValMemberTypeID
  JOIN dbo.vClubAddress  CA
       ON CA.ClubID = C.ClubID
  JOIN dbo.vValState CVS
       ON CA.ValStateID = CVS.ValStateID
  LEFT OUTER JOIN dbo.vValEFTOption VEO 
       ON (MS.ValEFTOptionID = VEO.ValEFTOptionID) 
  LEFT OUTER JOIN dbo.vEFTAccountDetail EAD 
       ON (MS.MembershipID = EAD.MembershipID) 
  LEFT OUTER JOIN dbo.vValPaymentType VPT 
       ON (EAD.ValPaymentTypeID = VPT.ValPaymentTypeID) 
  LEFT OUTER JOIN dbo.vValTerminationReason VTR 
       ON (VTR.ValTerminationReasonID = MS.ValTerminationReasonID)
 WHERE --(C.ClubName IN (SELECT ClubName FROM #Clubs) OR
       --@ClubList = 'All') AND
       C.DisplayUIFlag = 1 AND
       VMSS.Description IN ('Active', 'Pending Termination', 'Suspended') AND
       TB.TranBalanceAmount>0 AND
       MSB.CommittedBalance>0 AND
       VMT.Description = 'Primary'
 GROUP By MS.MembershipID, VEO.ValEFTOptionID, VEO.Description,
       VPT.Description, VR.Description, 
       C.ClubName, SA.FirstName, SA.LastName, SA.AddressLine1,
       SA.AddressLine2, SA.City, SA.Zip,
       SA.CompanyName, M.MemberID, VTR.Description,
       VS.Abbreviation, VC.Abbreviation,
       CA.AddressLine1, CA.AddressLine2,
       CA.City, CA.Zip, CVS.Abbreviation

DROP TABLE #Clubs
DROP TABLE #tmpList

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END




