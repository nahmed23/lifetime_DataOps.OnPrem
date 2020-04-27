

--
-- Returns list of Members that have no usage in a certain date range
--     designed for the Nonusage brio document, NoAttendance query
--
-- Parameters: a Clubname, a usage date range and a list of member types to report
--

CREATE  PROC dbo.mmsNonusage_NoAttendance_new (
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
CREATE TABLE #NonUsers (MemberID INT, FirstName VARCHAR(50), LastName VARCHAR(50), ValMemberTypeID INT,
						MembershipID INT, ValMembershipStatusID INT)
CREATE TABLE #ClubMembers (MemberID INT, FirstName VARCHAR(50), LastName VARCHAR(50), ValMemberTypeID INT,
						   MembershipID INT, ValMembershipStatusID INT)
CREATE TABLE #PrimaryMembers (MembershipID INT, FirstName VARCHAR(50), LastName VARCHAR(50))

EXEC procParseStringList @MemberTypeList
INSERT INTO #MemberTypes (MemberType) SELECT StringField FROM #tmpList
TRUNCATE TABLE #tmpList

--Get ClubID for the given club
DECLARE @ClubID INT
SELECT @ClubID = ClubID
FROM vClub
WHERE ClubName = @ClubName
  AND DisplayUIFlag = 1

--Get Description for the club's ValRegion
DECLARE @ValDescrip VARCHAR(50)
SELECT @ValDescrip = vr.Description
FROM vValRegion vr
JOIN vClub c
  ON c.ValRegionID = vr.ValRegionID
WHERE c.ClubID = @ClubID

--Find all active members at the specified club
INSERT INTO #ClubMembers
SELECT DISTINCT m.MemberID, m.FirstName, m.LastName, m.ValMemberTypeID,
				ms.MembershipID, ms.ValMembershipStatusID
FROM vMember m
JOIN vMembership ms
  ON ms.MembershipID = m.MembershipID
WHERE ms.ClubID = @ClubID
  AND m.ActiveFlag = 1              --Active Member
  AND m.JoinDate < @UsageStartDate  --Member before the given start date
  AND ms.ValMembershipStatusID = 4  --Active Membership
  AND m.LastName <> 'House Account'
  AND m.ValMemberTypeID IN (        --Find only members of the given types (Primary members used in next step)
							SELECT ValMemberTypeID
							FROM vValMemberType vmt
							JOIN #MemberTypes mt
							  ON mt.MemberType = vmt.Description
							  OR vmt.Description = 'Primary'
						   )

--Find all Primary Members for the memberships
INSERT INTO #PrimaryMembers
SELECT MembershipID, FirstName, LastName
FROM #ClubMembers
WHERE ValMemberTypeID = 1

--Find all members who didn't use a club for the given period
INSERT INTO #NonUsers
SELECT cm.MemberID, cm.FirstName, cm.LastName, cm.ValMemberTypeID,
	   cm.MembershipID, cm.ValMembershipStatusID
FROM #ClubMembers cm
WHERE NOT EXISTS (
                   SELECT mu.MemberID
                   FROM vMemberUsage mu
                   WHERE mu.MemberID = cm.MemberID
					 AND mu.UsageDateTime BETWEEN @UsageStartDate AND @UsageEndDate
                  )

DROP TABLE #ClubMembers

SELECT @ValDescrip RegionDescription, @ClubName ClubName, nu.MemberID,
       nu.FirstName MemberFirstname, nu.LastName MemberLastname, MSA.AddressLine1,
       MSA.AddressLine2, MSA.City, MSA.Zip,
       nu.MembershipID, pm.FirstName PrimaryFirstname, pm.LastName PrimaryLastname,
       MPN.HomePhoneNumber Membership_Home_Phone_Number, 
       MPN.BusinessPhoneNumber MembershipBusinessphonenumber, 
       VMT.Description MemberTypeDescription,
       VMS.Description MembershipStatusDescription, VS.Abbreviation StateAbbreviation,
       VC.Abbreviation CountryAbbreviation,
       SUM(CASE WHEN VCP.Description = 'Do Not Solicit Via Mail' THEN 1 ELSE 0 END) DoNotMailFlag,
       SUM(CASE WHEN VCP.Description = 'Do Not Solicit Via Phone' THEN 1 ELSE 0 END) DoNotPhoneFlag
  FROM #NonUsers nu
  JOIN #PrimaryMembers pm
	ON pm.MembershipID = nu.MembershipID
  JOIN dbo.vValMembershipStatus VMS
    ON nu.ValMembershipStatusID = VMS.ValMembershipStatusID
  JOIN dbo.vValMemberType VMT
    ON nu.ValMemberTypeID = VMT.ValMemberTypeID
  JOIN #MemberTypes MTS
    ON VMT.Description = MTS.MemberType
  JOIN dbo.vMembershipAddress MSA
    ON MSA.MembershipID = nu.MembershipID
  JOIN dbo.vMemberPhoneNumbers MPN
    ON MPN.MembershipID = nu.MembershipID
  JOIN dbo.vValState VS
    ON MSA.ValStateID = VS.ValStateID
  JOIN dbo.vValCountry VC
    ON MSA.ValCountryID = VC.ValCountryID
  LEFT JOIN dbo.vMembershipCommunicationPreference MCP
    ON nu.MembershipID = MCP.MembershipID
  LEFT JOIN dbo.vValCommunicationPReference VCP
    ON MCP.ValCommunicationPreferenceID = VCP.ValCommunicationPreferenceID
 WHERE VMS.Description = 'Active'
 GROUP BY nu.MemberID, nu.FirstName, nu.LastName, MSA.AddressLine1,
          MSA.AddressLine2, MSA.City, MSA.Zip, nu.MembershipID, pm.FirstName,
	      pm.LastName, MPN.HomePhoneNumber, MPN.BusinessPhoneNumber, 
          VMT.Description, VMS.Description, VS.Abbreviation, VC.Abbreviation
       
DROP TABLE #MemberTypes
DROP TABLE #tmpList
DROP TABLE #NonUsers

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END

