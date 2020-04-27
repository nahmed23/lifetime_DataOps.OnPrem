
-- =============================================
-- Object:			dbo.mmsMembershipCommunication
-- Author:			
-- Create date: 	
-- Description:		Returns memberships and their usage by club
-- Parameters:		requiring a list of clubs, a join date range, a list of Memberhip statuses
--					Alternate parameters include a list of membertypes, a gender list ('M' or 'F')
--					and a membershiptypelist. All lists are vertical bar separated strings and 
--					each that has a flag field will be ignored if not passed a zero
-- Modified date:	2/23/2009 GRB: added Corporate Code per request 3051, released 2/25/09? via dbcr_4213
--					3/13/2012 BSD: Changed DoNotEmail to new EmailSolicitationStatus
-- Exec mmsMembershipCommunication '141', 'Mar 1, 2011', 'Mar 2, 2011', 'Active', 'all', 'all', 'all', 'all'
-- =============================================

CREATE        PROC [dbo].[mmsMembershipCommunication] (
  @ClubIDList VARCHAR(2000),
  @JoinStartDate SMALLDATETIME,
  @JoinEndDate SMALLDATETIME,
  @MembershipStatusList VARCHAR(1000),
  @MemberTypeList VARCHAR(50),
  @GenderList VARCHAR(50),
  @MembershipTypeIDList VARCHAR(8000),
  @IncludeMembershipsWithMemberType VARCHAR(50)
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
CREATE TABLE #Clubs (ClubID VARCHAR(15))

EXEC procParseStringList @ClubIDList
INSERT INTO #Clubs (ClubID) SELECT StringField FROM #tmpList
TRUNCATE TABLE #tmpList

CREATE TABLE #MembershipStatus (MembershipStatus VARCHAR(50))
EXEC procParseStringList @MembershipStatusList
INSERT INTO #MembershipStatus (MembershipStatus) SELECT StringField FROM #tmpList
TRUNCATE TABLE #tmpList

CREATE TABLE #MemberType (MemberType VARCHAR(50))
IF @MemberTypeList <> 'All'
	BEGIN
	  EXEC procParseStringList @MemberTypeList
	  INSERT INTO #MemberType (MemberType) SELECT StringField FROM #tmpList
	  TRUNCATE TABLE #tmpList
	END
ELSE
	BEGIN
	  INSERT INTO #MemberType VALUES('All')
	END

CREATE TABLE #Gender (Gender VARCHAR(1))
IF @GenderList <> 'All'
	BEGIN
	  EXEC procParseStringList @GenderList
	  INSERT INTO #Gender (Gender) SELECT StringField FROM #tmpList
	  TRUNCATE TABLE #tmpList
	END
ELSE
	BEGIN
	  INSERT INTO #Gender VALUES('A')
	END

CREATE TABLE #MembershipTypeIDs (MembershipTypeID INT)
IF @MembershipTypeIDList <> 'All'
	BEGIN
	  EXEC procParseStringList @MembershipTypeIDList
	  INSERT INTO #MembershipTypeIDs (MembershipTypeID) SELECT StringField FROM #tmpList
	  TRUNCATE TABLE #tmpList
	END
ELSE
	BEGIN
	  INSERT INTO #MembershipTypeIDs VALUES(-100)
	END
  
SELECT VR.Description Region, C.ClubName Club, MS.MembershipID [Membership ID],
       VNP.Description Prefix, M.FirstName [First Name], M.MiddleName [Middle Name],
       M.LastName [Last Name], VNS.Description Suffix, M.DOB [Date of Birth],
       M.Gender, M.ActiveFlag, MSA.AddressLine1 [Address Line 1],
       MSA.AddressLine2 [Address Line 2], MSA.City, MSA.Zip,
       MSS.Description [Membership Status], VMT.Description MemberTypeDescription, M.MemberID,
       MPN.HomePhoneNumber, MPN.BusinessPhoneNumber, MS.ExpirationDate,
       E.FirstName AdvisorFirstname, E.LastName AdvisorLastname, C.DisplayUIFlag,
       M.JoinDate [Join Date], P.Description MembershipTypeDescription, 
       M.EmailAddress [Member e-mail Address],
       VS.Abbreviation StateAbbreviation, VC.Abbreviation CountryAbbreviation,
       SUM(CASE WHEN VCP.Description = 'Do Not Solicit Via Mail' THEN 1 ELSE NULL END) DoNotMailFlag,
       SUM(CASE WHEN VCP.Description = 'Do Not Solicit Via Phone' THEN 1 ELSE NULL END) DoNotPhoneFlag,
       --SUM(CASE WHEN VCP.Description = 'Do Not Solicit Via E-Mail' THEN 1 ELSE NULL END) DoNotEmailFlag,
       ISNULL(VCPS.Description,'Subscribed') EmailSolicitationStatus,
		co.CorporateCode				-- 2/23/2009 GRB: added per QC 3051
  FROM  dbo.vMembershipType MST
  JOIN dbo.vMembership MS			
       ON MS.MembershipTypeID = MST.MembershipTypeID
  LEFT JOIN dbo.vCompany co			-- 2/23/2009 GRB: added per QC 3051
		ON MS.CompanyID = co.CompanyID
  JOIN dbo.vMember M
       ON M.MembershipID = MS.MembershipID
  LEFT JOIN vEmailAddressStatus EAS
       ON M.EmailAddress = EAS.EmailAddress
      AND EAS.StatusFromDate <= GetDate()
      AND EAS.StatusThruDate > GetDate()
  LEFT JOIN vValCommunicationPreferenceStatus VCPS
       ON EAS.ValCommunicationPreferenceStatusID = VCPS.ValCommunicationPreferenceStatusID
  JOIN #Gender GR
       ON M.Gender = GR.Gender OR @GenderList = 'All'
  JOIN dbo.vProduct P
       ON MST.ProductID = P.ProductID
  JOIN #MembershipTypeIDs MTI
       ON P.ProductID = MTI.MembershipTypeID OR @MembershipTypeIDList = 'All'
  JOIN dbo.vClub C
       ON MS.ClubID = C.ClubID
  JOIN #Clubs CS
       ON C.ClubID = CS.ClubID
  JOIN dbo.vValRegion VR
       ON VR.ValRegionID = C.ValRegionID
  JOIN dbo.vValMemberType VMT
       ON VMT.ValMemberTypeID = M.ValMemberTypeID
  JOIN #MemberType MT
       ON VMT.Description = MT.MemberType OR MT.MemberType = 'All'
  JOIN dbo.vValMembershipStatus MSS
       ON MS.ValMembershipStatusID = MSS.ValMembershipStatusID
  JOIN #MembershipStatus TMSS
       ON MSS.Description = TMSS.MembershipStatus
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
 WHERE M.ActiveFlag = 1 AND
       M.JoinDate BETWEEN @JoinStartDate AND @JoinEndDate AND
       C.DisplayUIFlag = 1 AND
       P.DepartmentID = 1  AND	
       EXISTS (
              SELECT M2.MembershipID
                FROM dbo.vMember M2
                JOIN dbo.vValMemberType VMT2
                     ON M2.ValMemberTypeID = VMT2.ValMemberTypeID
               WHERE MS.MembershipID = M2.MembershipID AND
		     M2.ActiveFlag = 1 AND
                     (VMT2.Description = @IncludeMembershipsWithMemberType OR
                     @IncludeMembershipsWithMemberType = 'All')
              )
 GROUP BY VR.Description, C.ClubName, MS.MembershipID,
       VNP.Description, M.FirstName, M.MiddleName,
       M.LastName, VNS.Description, M.DOB,
       M.Gender, M.ActiveFlag, MSA.AddressLine1,
       MSA.AddressLine2, MSA.City, MSA.Zip,
       MSS.Description, VMT.Description, M.MemberID,
       MPN.HomePhoneNumber, MPN.BusinessPhoneNumber, MS.ExpirationDate,
       E.FirstName, E.LastName, C.DisplayUIFlag,
       M.JoinDate, P.Description, M.EmailAddress,
       VS.Abbreviation, VC.Abbreviation,VCP.Description,
       ISNULL(VCPS.Description,'Subscribed'),
		co.CorporateCode			-- 2/23/2009 GRB: added per QC 3051 
DROP TABLE #Clubs
DROP TABLE #MembershipStatus
DROP TABLE #MemberType
DROP TABLE #Gender
DROP TABLE #MembershipTypeIDs
DROP TABLE #tmpList

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END
