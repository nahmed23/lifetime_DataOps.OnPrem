



--
-- returns Membership Info originally used for the TargetMailingProgram Brio bqy
--
-- Parameters: a | separated list of clubnames
--
-- EXEC dbo.mmsTargetMailingProgram_MembershipCommunicationData '10|164|11|174|3'
--
CREATE  PROC dbo.mmsTargetMailingProgram_MembershipCommunicationData (
  @ClubIDList VARCHAR(2000)
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON
CREATE TABLE #tmpList (StringField Int)
CREATE TABLE #Clubs (ClubID Int)

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

--INSERT INTO #Clubs EXEC procParseStringList @ClubList
   EXEC procParseIntegerList @ClubIDList
   INSERT INTO #Clubs (ClubID) SELECT StringField FROM #tmpList

SELECT VR.Description Region, C.ClubName Club, MS.MembershipID [Membership ID],
       MSA.AddressLine1 [Address Line 1], MSA.AddressLine2 [Address Line 2], MSA.City,
       MSA.Zip, P.Name [Membership Type], VMS.Description [Membership Status],
       MPN.HomePhoneNumber, MPN.BusinessPhoneNumber, MS.ExpirationDate,
       C.DisplayUIFlag, P.Description MembershipTypeDescription, 
       VS.Abbreviation StateAbbreviation, VC.Abbreviation CountryAbbreviation, 
       PREF.DoNotMailFlag, PREF.DoNotPhoneFlag
  FROM dbo.vMembershipType MST
  JOIN dbo.vMembership MS
       ON MS.MembershipTypeID = MST.MembershipTypeID
  JOIN dbo.vProduct P
       ON MST.ProductID = P.ProductID
  JOIN dbo.vClub C
       ON MS.ClubID = C.ClubID
  JOIN #Clubs CS
       ON C.ClubID = CS.ClubID
--       ON C.ClubName = CS.ClubName
  JOIN dbo.vValRegion VR
       ON VR.ValRegionID = C.ValRegionID
  JOIN dbo.vValMembershipStatus VMS
       ON MS.ValMembershipStatusID = VMS.ValMembershipStatusID
  LEFT JOIN dbo.vMembershipAddress MSA
       ON MS.MembershipID = MSA.MembershipID
  LEFT JOIN dbo.vValCountry VC
       ON MSA.ValCountryID = VC.ValCountryID
  LEFT JOIN dbo.vValState VS
       ON MSA.ValStateID = VS.ValStateID
  LEFT JOIN dbo.vMemberPhoneNumbers MPN
       ON MS.MembershipID = MPN.MembershipID 
  LEFT JOIN (
       SELECT MCP.MembershipID,
              SUM(CASE WHEN VCP.Description = 'Do Not Solicit Via Mail' THEN 1 
                  ELSE NULL END) DoNotMailFlag,
              SUM(CASE WHEN VCP.Description = 'Do Not Solicit Via Phone' THEN 1 
                  ELSE NULL END) DoNotPhoneFlag
         FROM dbo.vMembershipCommunicationPreference MCP
         JOIN dbo.vValCommunicationPreference VCP
              ON MCP.ValCommunicationPreferenceID = VCP.ValCommunicationPreferenceID
        GROUP BY MCP.MembershipID
       ) PREF
       ON MS.MembershipID = PREF.MembershipID
 WHERE VMS.Description = 'Active' AND
       C.DisplayUIFlag = 1

DROP TABLE #Clubs
DROP TABLE #tmpList


-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END




