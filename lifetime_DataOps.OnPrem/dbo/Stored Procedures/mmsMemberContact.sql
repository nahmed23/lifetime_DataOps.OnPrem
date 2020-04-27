
--
-- Returns member/membership details for the Member Contact report (selected birthdays) 
-- Originally created for Member Activities group to target selected age groups
-- Parameters: clubname(s), Start date (birth year), End date (Birth year )and Birth Month
-- Exec mmsMemberContact 'Eagan, MN','01/01/60','01/01/70','10'

CREATE    PROC [dbo].[mmsMemberContact] (
  @ClubList VARCHAR(1000),
  @StartDate DATETIME,
  @EndDate DATETIME,
  @BirthMonth VARCHAR(100)
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
DECLARE @Identity AS INT
INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
SET @Identity = @@IDENTITY

CREATE TABLE #tmpList(StringField VARCHAR(50))

CREATE TABLE #Clubs (ClubName VARCHAR(50))
EXEC procParseStringList @ClubList
INSERT INTO #Clubs (ClubName)SELECT StringField FROM #tmpList
TRUNCATE TABLE #tmpList

CREATE TABLE #Months (BirthMonth VARCHAR(2))
EXEC procParseStringList @BirthMonth
INSERT INTO #Months (BirthMonth)SELECT StringField FROM #tmpList


SELECT M.MembershipID, M.MemberID, M.FirstName,
       M.LastName, M.DOB, M.Gender,VMSS.Description AS MembershipStatus,
       VMT.Description AS MemberTypeDescription, C.ClubName, MSA.AddressLine1,
       MSA.AddressLine2, MSA.City, VS.Abbreviation AS StateAbbreviation,
       MSA.Zip, VC.Abbreviation AS CountryAbbreviation, GETDATE() AS ReportDate,
       DATEDIFF ( day, M.DOB, (GETDATE()) ) AS AgeInDays,
       M2.FirstName AS PrimaryMemberFirstName, M2.LastName AS PrimaryMemberLastName,
       M2.EmailAddress AS PrimaryMemberEmailAddress, M.EmailAddress AS MemberEmailAddress,
       MP.AreaCode AS MembershipPrimaryAreacode,
       MP.Number AS MembershipPrimaryPhoneNumber,
       SUBSTRING(CONVERT(VARCHAR(10),M.DOB,110),1,2) AS DOBMonth,
       SUM(CASE WHEN VCP.Description = 'Do Not Solicit Via Mail' THEN 1
       ELSE 0 
       END) AS DoNotMailFlag,
       SUM(CASE WHEN VCP.Description = 'Do Not Solicit Via Phone' THEN 1
       ELSE 0 
       END) AS DoNotPhoneFlag,
       --SUM(CASE WHEN VCP.Description = 'Do Not Solicit Via E-Mail' THEN 1
       --ELSE 0 
       --END) AS DoNotEMailFlag
       ISNULL(VCPS.Description,'Subscribed') ReportingMemberEmailSolicitationStatus,
       ISNULL(PVCPS.Description,'Subscribed') PrimaryMemberEmailSolicitationStatus
  FROM dbo.vClub C
  JOIN dbo.vMembership MS
       ON MS.ClubID = C.ClubID
  JOIN #Clubs tC
       ON C.ClubName = tC.ClubName
  JOIN dbo.vMember M
       ON M.MembershipID = MS.MembershipID
  LEFT JOIN vEmailAddressStatus EAS
       ON M.EmailAddress = EAS.EmailAddress
      AND EAS.StatusFromDate <= GetDate()
      AND EAS.StatusThruDate > GetDate()
  LEFT JOIN vValCommunicationPreferenceStatus VCPS
       ON EAS.ValCommunicationPreferenceStatusID = VCPS.ValCommunicationPreferenceStatusID
  JOIN dbo.vMembershipAddress MSA
       ON MS.MembershipID = MSA.MembershipID
  JOIN dbo.vValCountry VC
       ON MSA.ValCountryID = VC.ValCountryID
  JOIN dbo.vValState VS
       ON MSA.ValStateID = VS.ValStateID
  JOIN dbo.vValMembershipStatus VMSS
       ON MS.ValMembershipStatusID = VMSS.ValMembershipStatusID
  JOIN dbo.vValMemberType VMT
       ON M.ValMemberTypeID = VMT.ValMemberTypeID
  JOIN dbo.vMember M2
       ON MS.MembershipID = M2.MembershipID
  LEFT JOIN vEmailAddressStatus PEAS --Primary
       ON M2.EmailAddress = PEAS.EmailAddress
      AND PEAS.StatusFromDate <= GetDate()
      AND PEAS.StatusThruDate > GetDate()
  LEFT JOIN vValCommunicationPreferenceStatus PVCPS --Primary
       ON PEAS.ValCommunicationPreferenceStatusID = PVCPS.ValCommunicationPreferenceStatusID
  LEFT JOIN dbo.vPrimaryPhone PP
       ON MS.MembershipID = PP.MembershipID
  LEFT JOIN dbo.vMembershipPhone MP
       ON PP.MembershipID = MP.MembershipID
       AND PP.ValPhoneTypeID = MP.ValPhoneTypeID
  LEFT JOIN dbo.vMembershipCommunicationPreference MSCP
       ON MSCP.MembershipID = MS.MembershipID AND
       MSCP.ActiveFlag = 1
  LEFT JOIN dbo.vValCommunicationPreference VCP
       ON MSCP.ValCommunicationPreferenceID = VCP.ValCommunicationPreferenceID       
 WHERE M.DOB >= @StartDate AND 
       M.DOB <= @EndDate AND
       SUBSTRING(CONVERT(VARCHAR(10),M.DOB,110),1,2)IN (SELECT BirthMonth FROM #Months) AND
       VMSS.Description IN ('Active', 'Late Activation', 'Non-Paid', 'Non-Paid, Late Activation', 'Pending Termination', 'Suspended') AND
       M.ActiveFlag = 1 AND
       MSA.ValAddressTypeID = 1 AND
       M2.ValMemberTypeID = 1 AND
       C.DisplayUIFlag = 1
Group by M.MembershipID, M.MemberID, M.FirstName,
       M.LastName, M.DOB, M.Gender,VMSS.Description,
       VMT.Description, C.ClubName, MSA.AddressLine1,
       MSA.AddressLine2, MSA.City, VS.Abbreviation,
       MSA.Zip, VC.Abbreviation,
       DATEDIFF ( day, M.DOB, (GETDATE()) ),
       M2.FirstName, M2.LastName,
       M2.EmailAddress, M.EmailAddress,
       MP.AreaCode, MP.Number,
       ISNULL(VCPS.Description,'Subscribed'),
       ISNULL(PVCPS.Description,'Subscribed')

DROP TABLE #Clubs
DROP TABLE #Months
DROP TABLE #tmpList

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END
