







--
-- Returns list of Members that have no usage in a certain date range
--     designed for the Nonusage brio document, NoAttendance query
--
-- Parameters: a Clubname, a usage date range and a list of member types to report
--

CREATE  PROC dbo.mmsNonusage_NoAttendance_original (
  @ClubName VARCHAR(50),
  @UsageStartDate SMALLDATETIME,
  @UsageEndDate SMALLDATETIME,
  @MemberTypeList VARCHAR(1000)
  )
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

CREATE TABLE #tmpList (StringField VARCHAR(50))
CREATE TABLE #MemberTypes (MemberType VARCHAR(50))
--INSERT INTO #MemberTypes EXEC procParseStringList @MemberTypeList
  EXEC procParseStringList @MemberTypeList
  INSERT INTO #MemberTypes (MemberType) SELECT StringField FROM #tmpList
  TRUNCATE TABLE #tmpList


SELECT VR.Description RegionDescription, C.ClubName, M1.MemberID,
       M1.FirstName MemberFirstname, M1.LastName MemberLastname, MSA.AddressLine1,
       MSA.AddressLine2, MSA.City, MSA.Zip,
       MS.MembershipID, M2.FirstName PrimaryFirstname, M2.LastName PrimaryLastname,
       MPN.HomePhoneNumber Membership_Home_Phone_Number, 
       MPN.BusinessPhoneNumber MembershipBusinessphonenumber, 
       VMT.Description MemberTypeDescription,
       VMS.Description MembershipStatusDescription, VS.Abbreviation StateAbbreviation,
       VC.Abbreviation CountryAbbreviation,
       SUM(CASE WHEN VCP.Description = 'Do Not Solicit Via Mail' THEN 1 ELSE 0 END) DoNotMailFlag,
       SUM(CASE WHEN VCP.Description = 'Do Not Solicit Via Phone' THEN 1 ELSE 0 END) DoNotPhoneFlag
  FROM dbo.vMembership MS
  JOIN dbo.vValMembershipStatus VMS
       ON MS.ValMembershipStatusID = VMS.ValMembershipStatusID
  JOIN dbo.vClub C
       ON MS.ClubID = C.ClubID
  JOIN dbo.vMember M1
       ON M1.MembershipID = MS.MembershipID
  JOIN dbo.vValMemberType VMT
       ON M1.ValMemberTypeID = VMT.ValMemberTypeID
  JOIN #MemberTypes MTS
       ON VMT.Description = MTS.MemberType
  JOIN dbo.vValRegion VR
       ON C.ValRegionID = VR.ValRegionID
  JOIN dbo.vMembershipAddress MSA
       ON MSA.MembershipID = MS.MembershipID
  JOIN dbo.vMemberPhoneNumbers MPN
       ON MPN.MembershipID = MS.MembershipID
  JOIN dbo.vMember M2
       ON M2.MembershipID = MS.MembershipID
  JOIN dbo.vValState VS
       ON MSA.ValStateID = VS.ValStateID
  JOIN dbo.vValCountry VC
       ON MSA.ValCountryID = VC.ValCountryID
  LEFT JOIN dbo.vMembershipCommunicationPreference MCP
       ON MS.MembershipID = MCP.MembershipID
  LEFT JOIN dbo.vValCommunicationPReference VCP
       ON MCP.ValCommunicationPreferenceID = VCP.ValCommunicationPreferenceID
 WHERE VMS.Description = 'Active' AND
       C.ClubName = @ClubName AND
       M1.JoinDate < @UsageStartDate AND
       M1.ActiveFlag = 1 AND
       C.DisplayUIFlag = 1 AND
       M2.ValMemberTypeID = 1 AND
       --VMT.Description IN (SELECT MemberType FROM #MemberTypes) AND
       VMS.Description = 'Active' AND
       NOT EXISTS (
              SELECT MU.MemberID
                FROM dbo.vMemberUsage MU
               WHERE MU.MemberID = M1.MemberID AND
                     MU.UsageDateTime BETWEEN @UsageStartDate AND @UsageEndDate
              )
 GROUP BY VR.Description, C.ClubName, M1.MemberID,
       M1.FirstName, M1.LastName, MSA.AddressLine1,
       MSA.AddressLine2, MSA.City, MSA.Zip,
       MS.MembershipID, M2.FirstName, M2.LastName,
       MPN.HomePhoneNumber, MPN.BusinessPhoneNumber, VMT.Description,
       VMS.Description, VS.Abbreviation, VC.Abbreviation
       
DROP TABLE #MemberTypes
DROP TABLE #tmpList

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END








