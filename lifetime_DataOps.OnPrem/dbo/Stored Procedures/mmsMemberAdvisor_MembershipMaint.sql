


--
-- returns member information by advisor including their communications preferences
--
-- Parameters: a vertical bar separated list of clubnames and a date range
--

CREATE  PROC dbo.mmsMemberAdvisor_MembershipMaint (
  @ClubNameList VARCHAR(1000),
  @StartDate SMALLDATETIME,
  @EndDate SMALLDATETIME
  )
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

CREATE TABLE #ClubNames (ClubName VARCHAR(50))
INSERT INTO #ClubNames (ClubName) EXEC procParseStringList @ClubNameList

-- Report Logging
DECLARE @Identity AS INT
INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
SET @Identity = @@IDENTITY

SELECT MS.CreatedDateTime, M.JoinDate, M.MemberID,
       M.FirstName PrimaryFirstname, M.LastName PrimaryLastname, C1.ClubName MembershipClubname,
       E.EmployeeID AdvisorEmployeeID, E.FirstName AdvisorFirstname,
       E.LastName AdvisorLastname, P.Description MembershipTypeDescription,
       MSA.AddressLine1, MSA.AddressLine2,
       MSA.City, MSA.Zip, MSA.ValAddressTypeID,
       MPN.HomePhoneNumber, MPN.BusinessPhoneNumber, C2.ClubName AdvisorClubname,
       MS.MembershipID, M.EmailAddress MemberEmailaddress, VS.Abbreviation StateAbbreviation,
       VC.Abbreviation CountryAbbreviation,
       SUM(CASE WHEN VCP.Description = 'Do Not Solicit Via Mail' THEN 1 ELSE NULL END) DoNotMailFlag,
       SUM(CASE WHEN VCP.Description = 'Do Not Solicit Via Phone' THEN 1 ELSE NULL END) DoNotPhoneFlag,
       SUM(CASE WHEN VCP.Description = 'Do Not Solicit Via E-Mail' THEN 1 ELSE NULL END) DoNotEmailFlag
  FROM dbo.vMember M
  JOIN dbo.vMembership MS 
       ON M.MembershipID=MS.MembershipID
  JOIN dbo.vValMembershipStatus VMS
       ON MS.ValMembershipStatusID=VMS.ValMembershipStatusID
  JOIN dbo.vClub C1
       ON MS.ClubID=C1.ClubID
  JOIN dbo.vEmployee E
       ON MS.AdvisorEmployeeID=E.EmployeeID
  JOIN dbo.vMembershipType MST
       ON MS.MembershipTypeID=MST.MembershipTypeID
  JOIN dbo.vProduct P
       ON MST.ProductID=P.ProductID
  JOIN dbo.vClub C2
       ON E.ClubID=C2.ClubID
  LEFT OUTER JOIN dbo.vMemberPhoneNumbers MPN 
       ON MPN.MembershipID=MS.MembershipID
  LEFT OUTER JOIN dbo.vMembershipAddress MSA 
       ON MS.MembershipID=MSA.MembershipID
  LEFT OUTER JOIN dbo.vValState VS 
       ON MSA.ValStateID=VS.ValStateID
  LEFT OUTER JOIN dbo.vValCountry VC 
       ON MSA.ValCountryID=VC.ValCountryID
  LEFT JOIN dbo.vMembershipCommunicationPreference MCP
       ON MS.MembershipID = MCP.MembershipID AND
       MCP.ActiveFlag = 1
  LEFT JOIN dbo.vValCommunicationPreference VCP
       ON MCP.ValCommunicationPreferenceID = VCP.ValCommunicationPreferenceID
 WHERE (MS.CreatedDateTime BETWEEN @StartDate AND @EndDate OR 
       (MS.CreatedDateTime IS NULL AND
       M.JoinDate BETWEEN @StartDate AND @EndDate)) AND
       M.ValMemberTypeID=1 AND
       VMS.Description IN ('Active', 'Late Activation', 'Non-Paid', 'Non-Paid, Late Activation', 'Suspended') AND
       C2.ClubName IN (SELECT ClubName FROM #ClubNames) AND
       C2.DisplayUIFlag=1
 GROUP BY MS.CreatedDateTime, M.JoinDate, M.MemberID,
       M.FirstName, M.LastName, C1.ClubName,
       E.EmployeeID, E.FirstName,
       E.LastName, P.Description,
       MSA.AddressLine1, MSA.AddressLine2,
       MSA.City, MSA.Zip, MSA.ValAddressTypeID,
       MPN.HomePhoneNumber, MPN.BusinessPhoneNumber, C2.ClubName,
       MS.MembershipID, M.EmailAddress, VS.Abbreviation,
       VC.Abbreviation

DROP TABLE #ClubNames

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END



