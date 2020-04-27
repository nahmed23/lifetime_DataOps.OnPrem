







--
-- Returns memberships which should receive the Experience Life Magazine
--
-- Parameters: requiring a list of clubs, a join date range
--   
--

-- EXEC mmsELSubscription_MailingList 'Algonquin, IL', '10/1/05', '10/31/05'
-- EXEC mmsELSubscription_MailingList 'Minneapolis Athletic Club', '1/1/1900', '1/1/2050'
CREATE                   PROC dbo.mmsELSubscription_MailingList (
  @ClubList VARCHAR(8000),
  @JoinStartDate SMALLDATETIME,
  @JoinEndDate SMALLDATETIME
  )
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

DECLARE @ToDay DATETIME
SET @ToDay  =  CONVERT(DATETIME, CONVERT(VARCHAR, GETDATE(), 102), 102)

-- ****************************************
-- From Proc dbo.mmsMembershipCommunication
-- ****************************************
CREATE TABLE #tmpList (StringField NVARCHAR(50))
CREATE TABLE #Clubs (ClubName NVARCHAR(50))
EXEC procParseStringList @clubList
INSERT INTO #Clubs (ClubName) SELECT StringField FROM #tmpList
TRUNCATE TABLE #tmpList

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

SELECT M.MemberID [Member ID], VNP.Description Prefix, 
       M.FirstName [First Name], M.LastName [Last Name], 
       VNS.Description Suffix, 
       MSA.AddressLine1, MSA.AddressLine2, 
       MSA.City, S.Abbreviation AS State, MSA.Zip, VC.Abbreviation Country, 
       C.ClubName Club, VR.Description Region, P.Description [Membership Type]
  FROM  dbo.vMembershipType MST
  JOIN dbo.vMembership MS
       ON MS.MembershipTypeID = MST.MembershipTypeID
  JOIN dbo.vMember M
       ON M.MembershipID = MS.MembershipID
  JOIN dbo.vProduct P
       ON MST.ProductID = P.ProductID
  JOIN dbo.vClub C
       ON MS.ClubID = C.ClubID
  JOIN #Clubs CS
       ON C.ClubName = CS.ClubName
  JOIN dbo.vValRegion VR
       ON VR.ValRegionID = C.ValRegionID
  JOIN dbo.vValMembershipStatus MSS
       ON MS.ValMembershipStatusID = MSS.ValMembershipStatusID
  LEFT JOIN dbo.vValNamePrefix VNP
       ON M.ValNamePrefixID = VNP.ValNamePrefixID
  LEFT JOIN dbo.vValNameSuffix VNS
       ON M.ValNameSuffixID = VNS.ValNameSuffixID 
  LEFT JOIN dbo.vMembershipAddress MSA
       ON MS.MembershipID = MSA.MembershipID
  LEFT JOIN dbo.vValCountry VC
       ON MSA.ValCountryID = VC.ValCountryID
  LEFT JOIN dbo.vValState VS
       ON MSA.ValStateID = VS.ValStateID
  LEFT JOIN dbo.vMemberPhoneNumbers MPN
       ON MS.MembershipID = MPN.MembershipID
  LEFT JOIN dbo.vEmployee E
       ON MS.AdvisorEmployeeID = E.EmployeeID
  LEFT JOIN dbo.vMembershipCommunicationPreference MCP
       ON MS.MembershipID = MCP.MembershipID AND MCP.ActiveFlag = 1
  LEFT JOIN dbo.vValCommunicationPreference VCP
       ON MCP.ValCommunicationPreferenceID = VCP.ValCommunicationPreferenceID
  LEFT JOIN dbo.vValState S
       ON MSA.ValStateID = S.ValStateID
 WHERE M.ActiveFlag = 1 AND
       M.JoinDate BETWEEN @JoinStartDate AND @JoinEndDate AND
       C.DisplayUIFlag = 1 AND 
       P.DepartmentID = 1  AND 
       MSS.Description IN ('Active', 'Late Activation', 'Non-Paid', 'Non-Paid, Late Activation', 'Pending Termination') AND 
       (VCP.Description <> 'Do Not Solicit Via Mail' OR VCP.Description is Null) AND 
       ValMemberTypeID = 1 AND
       M.MemberID NOT IN (
		SELECT M.MemberID
		FROM dbo.vMember M
		  JOIN dbo.vMembership MS
		       ON MS.MembershipID = M.MembershipID
		  JOIN dbo.vMembershipType MST
		       ON MS.MembershipTypeID = MST.MembershipTypeID
		  JOIN dbo.vProduct P
		       ON MST.ProductID = P.ProductID
		  JOIN dbo.vClub C
		       ON MS.ClubID = C.ClubID
		  JOIN #Clubs CS
		       ON C.ClubName = CS.ClubName
		  JOIN dbo.vValMembershipStatus MSS
		       ON MS.ValMembershipStatusID = MSS.ValMembershipStatusID
		  LEFT JOIN dbo.vMembershipCommunicationPreference MCP
		       ON MS.MembershipID = MCP.MembershipID AND MCP.ActiveFlag = 1
		  LEFT JOIN dbo.vValCommunicationPreference VCP
		       ON MCP.ValCommunicationPreferenceID = VCP.ValCommunicationPreferenceID
		WHERE M.JoinDate BETWEEN @JoinStartDate AND @JoinEndDate AND
		       C.DisplayUIFlag = 1 AND 
		       P.DepartmentID = 1  AND 
		       MSS.Description IN ('Active', 'Late Activation', 'Non-Paid', 'Non-Paid, Late Activation', 'Pending Termination') AND 
		       VCP.Description = 'Do Not Solicit Via Mail' AND 
		       ValMemberTypeID = 1)

 GROUP BY M.MemberID, VNP.Description, M.FirstName, M.LastName, 
       VNS.Description, MSA.AddressLine1, MSA.AddressLine2, 
       MSA.City, S.Abbreviation, MSA.Zip, VC.Abbreviation, 
       C.ClubName, VR.Description, P.Description

UNION

-- ********************************************************
-- From Proc dbo.mmsMembershipStatus_RecurrentProductStatus
-- ********************************************************
SELECT M.MemberID [Member ID], VNP.Description Prefix, 
	 M.FirstName [First Name], M.LastName [Last Name],
	 VNS.Description Suffix,
	 MSA.AddressLine1, MSA.AddressLine2, 
	 MSA.City, S.Abbreviation AS State, MSA.Zip, VC.Description Country, 
	 C.ClubName Club, VR.Description Region, P.Description [Membership Type]
    FROM dbo.vClub C
    JOIN #Clubs CS
       ON C.ClubName = CS.ClubName
    JOIN dbo.vMembership MS
         ON C.ClubID = MS.ClubID
    JOIN dbo.vMembershipAddress MA
         ON MS.MembershipID = MA.MembershipID
    JOIN dbo.vValState S
         ON MA.ValStateID = S.ValStateID
    JOIN dbo.vMembershipRecurrentProduct MSRP
         ON MS.MembershipID = MSRP.MembershipID
    JOIN dbo.vProduct P
         ON P.ProductID = MSRP.ProductID
    JOIN dbo.vClubProduct CP
         ON P.ProductID = CP.ProductID
         AND C.ClubID = CP.ClubID
    JOIN dbo.vValRegion VR
         ON C.ValRegionID = VR.ValRegionID
    JOIN dbo.vMember M
         ON M.MembershipID = MSRP.MembershipID
    LEFT JOIN dbo.vValRecurrentProductType VRP
         ON P.ValRecurrentProductTypeID = VRP.ValRecurrentProductTypeID
    LEFT JOIN dbo.vValNamePrefix VNP
         ON M.ValNamePrefixID = VNP.ValNamePrefixID
    LEFT JOIN dbo.vValNameSuffix VNS
         ON M.ValNameSuffixID = VNS.ValNameSuffixID 
    LEFT JOIN dbo.vMembershipAddress MSA
         ON MS.MembershipID = MSA.MembershipID
    LEFT JOIN dbo.vValCountry VC
         ON MSA.ValCountryID = VC.ValCountryID
   WHERE(MSRP.TerminationDate >= @Today OR 
	MSRP.TerminationDate Is Null) AND
        MSRP.ActivationDate <= @Today AND
        M.ValMemberTypeID = 1

DROP TABLE #Clubs

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END








