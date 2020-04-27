
--
-- Returns list of Members that have no usage in a certain date range
--     designed for the Nonusage brio document, NoAttendance query
--
-- Parameters: a list of Clubs, a usage date range and a list of member types to report
--
CREATE   PROC [dbo].[mmsNonusage_NoAttendance] (
  @ClubIDList VARCHAR(2000),
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
CREATE TABLE #Clubs (ClubID INT)

EXEC procParseStringList @MemberTypeList
INSERT INTO #MemberTypes (MemberType) SELECT StringField FROM #tmpList
TRUNCATE TABLE #tmpList

--Set the List of Clubs
IF @ClubIDList <> 'All'
BEGIN
   EXEC procParseIntegerList @ClubIDList
   INSERT INTO #Clubs (ClubID) SELECT StringField FROM #tmpList
   TRUNCATE TABLE #tmpList
END
ELSE
BEGIN
  INSERT INTO #Clubs SELECT ClubID FROM dbo.vClub
END

SELECT VR.Description RegionDescription, C.ClubName, M.MemberID,
       M.FirstName MemberFirstname, M.LastName MemberLastname, MSA.AddressLine1,
       MSA.AddressLine2, MSA.City, MSA.Zip,
       M.MembershipID, Primarys.FirstName PrimaryFirstname, Primarys.LastName PrimaryLastname,
       MPN.HomePhoneNumber Membership_Home_Phone_Number, 
       MPN.BusinessPhoneNumber MembershipBusinessphonenumber, 
       VMT.Description MemberTypeDescription,
       VMS.Description MembershipStatusDescription, VS.Abbreviation StateAbbreviation,
       VC.Abbreviation CountryAbbreviation,
       SUM(CASE WHEN VCP.Description = 'Do Not Solicit Via Mail' THEN 1 ELSE 0 END) DoNotMailFlag,
       SUM(CASE WHEN VCP.Description = 'Do Not Solicit Via Phone' THEN 1 ELSE 0 END) DoNotPhoneFlag
  FROM dbo.vMember M
  JOIN vMembership MS
    ON MS.MembershipID = M.MembershipID
  JOIN dbo.vClub C
    ON C.ClubID = MS.ClubID
  JOIN #Clubs CS
    ON C.ClubID = CS.ClubID --OR @ClubIDList = 'All')
  JOIN dbo.vValRegion VR
    ON VR.ValRegionID = C.ValRegionID
  JOIN vMember Primarys
    ON Primarys.MembershipID = M.MembershipID
  JOIN dbo.vValMembershipStatus VMS
    ON MS.ValMembershipStatusID = VMS.ValMembershipStatusID
  JOIN dbo.vValMemberType VMT
    ON M.ValMemberTypeID = VMT.ValMemberTypeID
  JOIN #MemberTypes MTS
    ON VMT.Description = MTS.MemberType
  JOIN dbo.vMembershipAddress MSA
    ON MSA.MembershipID = M.MembershipID
  JOIN dbo.vMemberPhoneNumbers MPN
    ON MPN.MembershipID = M.MembershipID
  JOIN dbo.vValState VS
    ON MSA.ValStateID = VS.ValStateID
  JOIN dbo.vValCountry VC
    ON MSA.ValCountryID = VC.ValCountryID
  LEFT JOIN dbo.vMembershipCommunicationPreference MCP
    ON M.MembershipID = MCP.MembershipID
  LEFT JOIN dbo.vValCommunicationPReference VCP
    ON MCP.ValCommunicationPreferenceID = VCP.ValCommunicationPreferenceID
 WHERE M.ActiveFlag = 1                    --Active Member
   AND M.JoinDate < @UsageStartDate        --Member before the given start date
   AND MS.ValMembershipStatusID = 4        --Active Membership
   AND Primarys.LastName <> 'House Account' --Not a House Account
   AND Primarys.ValMemberTypeID = 1        --Primary Member
   AND NOT EXISTS ( --Exclude Members with Usage
                   SELECT MU.MemberID
                   FROM vMemberUsage MU
                   WHERE MU.MemberID = M.MemberID
					 AND MU.UsageDateTime BETWEEN @UsageStartDate AND @UsageEndDate
                  )
 GROUP BY VR.Description, C.ClubName, M.MemberID, M.FirstName, M.LastName, MSA.AddressLine1,
          MSA.AddressLine2, MSA.City, MSA.Zip, M.MembershipID, Primarys.FirstName,
	      Primarys.LastName, MPN.HomePhoneNumber, MPN.BusinessPhoneNumber, 
          VMT.Description, VMS.Description, VS.Abbreviation, VC.Abbreviation
       
DROP TABLE #MemberTypes
DROP TABLE #tmpList
DROP TABLE #Clubs

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END
