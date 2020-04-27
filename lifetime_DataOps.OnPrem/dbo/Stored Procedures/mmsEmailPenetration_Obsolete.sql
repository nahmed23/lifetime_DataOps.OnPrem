
CREATE     PROC [dbo].[mmsEmailPenetration_Obsolete] (
  @ClubIDList VARCHAR(2000)
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
CREATE TABLE #Clubs (ClubID VARCHAR(15))
IF @ClubIDList <> 'All'
BEGIN
--   INSERT INTO #Clubs EXEC procParseStringList @ClubList
   EXEC procParseStringList @ClubIDList
   INSERT INTO #Clubs (ClubID) SELECT StringField FROM #tmpList
   TRUNCATE TABLE #tmpList
END

SELECT C.ClubID, C.ClubName, 
       M.MemberID AS [Non-Employee Memberships],
       M.EmailAddress AS [Memberships With E-mail On File], 
       VR.Description AS RegionDescription, 
       MAX ( GETDATE() )AS ReportDate,
       M.EmailAddress,
       --SUM (CASE WHEN VCP.Description = 'Do Not Solicit Via E-mail' 
       --     THEN 1 ELSE 0 
       --     END) AS [Memberships Opting Out of Marketing E-mail],
       SUM(CASE WHEN ISNULL(VCPS.Description,'Subscribed') <> 'Subscribed' THEN 1 ELSE 0 END) [Memberships Opting Out of Marketing E-mail],
       --SUM (CASE WHEN M.EmailAddress IS NOT NULL AND
       --     VCP.Description = 'Do Not Solicit Via E-Mail'
       --     THEN 1 ELSE 0
       --     END) AS [Memberships Opting Out with E-mail On File]
       SUM(CASE WHEN M.EmailAddress IS NOT NULL AND ISNULL(VCPS.Description,'Subscribed') <> 'Subscribed' THEN 1 ELSE 0 END) [Memberships Opting Out with E-mail On File]
  FROM dbo.vClub C
  JOIN #Clubs CS
       ON C.ClubID = CS.ClubID
  JOIN dbo.vMembership MS
       ON C.ClubID = MS.ClubID
  JOIN dbo.vMember M
       ON MS.MembershipID = M.MembershipID
  JOIN dbo.vValMembershipStatus VMSS
       ON VMSS.ValMembershipStatusID = MS.ValMembershipStatusID
  JOIN dbo.vMembershipType MST
       ON MS.MembershipTypeID = MST.MembershipTypeID
  JOIN dbo.vProduct P
       ON MST.ProductID = P.ProductID
  JOIN dbo.vValRegion VR 
       ON C.ValRegionID = VR.ValRegionID
  --LEFT JOIN dbo.vMembershipCommunicationPreference MSCP
  --     ON MSCP.MembershipID = MS.MembershipID
  --LEFT JOIN dbo.vValCommunicationPreference VCP
  --     ON MSCP.ValCommunicationPreferenceID = VCP.ValCommunicationPreferenceID 
  LEFT JOIN vEmailAddressStatus EAS
       ON M.EmailAddress = EAS.EmailAddress
      AND EAS.StatusFromDate <= GetDate()
      AND EAS.StatusThruDate > GetDate()
  LEFT JOIN vValCommunicationPreferenceStatus VCPS
       ON EAS.ValCommunicationPreferenceStatusID = VCPS.ValCommunicationPreferenceStatusID
 WHERE M.ValMemberTypeID = 1 
   AND VMSS.Description IN ('Active', 'Late Activation', 'Non-Paid', 'Non-Paid, Late Activation', 'Pending Termination', 'Suspended') 
   AND (NOT P.Description LIKE '%Employee%') 
   AND C.DisplayUIFlag = 1 
 GROUP BY C.ClubID, C.ClubName, VR.Description, M.MemberID, M.EmailAddress
 
 DROP TABLE #Clubs
 DROP TABLE #tmpList

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END
