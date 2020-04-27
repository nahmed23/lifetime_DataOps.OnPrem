









--
-- Returns recordset used in MembershipComposition Brio bqy
--
-- Parameters: A string that is either 'Terminated' or 'Non-Terminated',
--     a list of clubIDs (| separated)
--     a date range that will be join dates for 'Terminated' or join dates for 'Non-Terminated'
--     a list of membertypes (| separated) 
--
-- Revised 2 Jun 2005 RKB, Added vCompany.CorporateCode,
--                               vCompany.CompanyName,
--                           and vClub.DomainNamePrefix
--

CREATE        PROC dbo.mmsMembershipComposition (
  @TerminatedOrNonTerminated VARCHAR(50),
  @ClubIDList VARCHAR(2000),
  @StartDate SMALLDATETIME,
  @EndDate SMALLDATETIME,
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

IF NOT @TerminatedOrNonTerminated IN ('Terminated', 'Non-Terminated')
BEGIN
  RAISERROR('Parameter @TerminatedOrNonTerminated expects either ''Terminated'' or ''Non-Terminated''', 16, 1)
  RETURN
END

CREATE TABLE #tmpList (StringField VARCHAR(20))
CREATE TABLE #Clubs (ClubID INT)
  EXEC procParseIntegerList @ClubIDList
  INSERT INTO #Clubs (ClubID) SELECT StringField FROM #tmpList
  TRUNCATE TABLE #tmpList

CREATE TABLE #MemberTypes (MemberType VARCHAR(50))
  EXEC procParseStringList @MemberTypeList
  INSERT INTO #MemberTypes (MemberType) SELECT StringField FROM #tmpList
  TRUNCATE TABLE #tmpList




IF @TerminatedOrNonTerminated = 'Terminated'

SELECT VR.Description RegionDescription, C.DomainNamePrefix, C.ClubName,
       M.MemberID, M.FirstName, M.LastName, M.JoinDate,
       MS.CreatedDateTime, VPT.Description PhoneTypeDescription, MSP.AreaCode,
       MSP.Number, MS.MembershipID, VMS.Description MembershipStatusDescription,
       P.ProductID, P.Description ProductDescription, M.DOB,
       DATEDIFF ( year, M.DOB, GETDATE() ) Age,
       VMT.Description MemberTypeDescription, MA.AddressLine1, MA.AddressLine2,
       MA.City, VS.Abbreviation StateAbbreviation, MA.Zip,
       VC.Abbreviation CountryAbbreviation, GETDATE() QueryDate, M.Gender,
       VMT.SortOrder MemberTypeSortOrder, MS.CompanyID, CO.CompanyName,
       CO.CorporateCode, MTFS.Description MembershipSizeDescription,
       MS.ExpirationDate, VTR.Description TermReasonDescription
  FROM dbo.vMember M
  JOIN dbo.vMembership MS
       ON M.MembershipID = MS.MembershipID
  JOIN dbo.vClub C
       ON MS.ClubID = C.ClubID
  JOIN dbo.vValRegion VR
       ON C.ValRegionID = VR.ValRegionID
  JOIN dbo.vMembershipType MST
       ON MS.MembershipTypeID = MST.MembershipTypeID
  JOIN dbo.vProduct P
       ON MST.ProductID = P.ProductID
  JOIN dbo.vValMembershipStatus VMS
       ON MS.ValMembershipStatusID = VMS.ValMembershipStatusID
  JOIN dbo.vValMemberType VMT
       ON M.ValMemberTypeID = VMT.ValMemberTypeID
  JOIN dbo.vValMembershipTypeFamilyStatus MTFS
       ON MST.ValMembershipTypeFamilyStatusID = MTFS.ValMembershipTypeFamilyStatusID
  LEFT JOIN dbo.vCompany CO
       ON MS.CompanyID = CO.CompanyID
  LEFT JOIN dbo.vPrimaryPhone PP
       ON MS.MembershipID = PP.MembershipID
  LEFT JOIN dbo.vMembershipPhone MSP
       ON PP.MembershipID = MSP.MembershipID AND
       PP.ValPhoneTypeID = MSP.ValPhoneTypeID
  LEFT JOIN dbo.vValPhoneType VPT
       ON MSP.ValPhoneTypeID = VPT.ValPhoneTypeID
  LEFT JOIN dbo.vMembershipAddress MA
       ON MS.MembershipID = MA.MembershipID
  LEFT JOIN dbo.vValState VS
       ON MA.ValStateID = VS.ValStateID
  LEFT JOIN dbo.vValCountry VC
       ON MA.ValCountryID = VC.ValCountryID
  LEFT JOIN dbo.vValTerminationReason VTR
       ON VTR.ValTerminationReasonID = MS.ValTerminationReasonID 
 WHERE M.ActiveFlag = 1 AND
       VMT.Description IN (SELECT MemberType FROM #MemberTypes) AND
       C.DisplayUIFlag = 1 AND
       C.ClubID IN (SELECT ClubID FROM #Clubs) AND
       VMS.Description = 'Terminated' AND
       MS.ExpirationDate BETWEEN @StartDate AND @EndDate AND
       MST.ShortTermMembershipFlag = 0
       
ELSE

SELECT VR.Description RegionDescription, C.DomainNamePrefix, C.ClubName,
       M.MemberID, M.FirstName, M.LastName, M.JoinDate,
       MS.CreatedDateTime, VPT.Description PhoneTypeDescription, MSP.AreaCode,
       MSP.Number, MS.MembershipID, VMS.Description MembershipStatusDescription,
       P.ProductID, P.Description ProductDescription, M.DOB,
       DATEDIFF ( year, M.DOB, GETDATE() ) Age,
       VMT.Description MemberTypeDescription, MA.AddressLine1, MA.AddressLine2,
       MA.City, VS.Abbreviation StateAbbreviation, MA.Zip,
       VC.Abbreviation CountryAbbreviation, GETDATE() QueryDate, M.Gender,
       VMT.SortOrder MemberTypeSortOrder, MS.CompanyID, CO.CompanyName,
       CO.CorporateCode, MTFS.Description MembershipSizeDescription,
       MS.ExpirationDate, VTR.Description TermReasonDescription
  FROM dbo.vMember M
  JOIN dbo.vMembership MS
       ON M.MembershipID = MS.MembershipID
  JOIN dbo.vClub C
       ON MS.ClubID = C.ClubID
  JOIN dbo.vValRegion VR
       ON C.ValRegionID = VR.ValRegionID
  JOIN dbo.vMembershipType MST
       ON MS.MembershipTypeID = MST.MembershipTypeID
  JOIN dbo.vProduct P
       ON MST.ProductID = P.ProductID
  JOIN dbo.vValMembershipStatus VMS
       ON MS.ValMembershipStatusID = VMS.ValMembershipStatusID
  JOIN dbo.vValMemberType VMT
       ON M.ValMemberTypeID = VMT.ValMemberTypeID
  JOIN dbo.vValMembershipTypeFamilyStatus MTFS
       ON MST.ValMembershipTypeFamilyStatusID = MTFS.ValMembershipTypeFamilyStatusID
  LEFT JOIN dbo.vCompany CO
       ON MS.CompanyID = CO.CompanyID
  LEFT JOIN dbo.vPrimaryPhone PP
       ON MS.MembershipID = PP.MembershipID
  LEFT JOIN dbo.vMembershipPhone MSP
       ON PP.MembershipID = MSP.MembershipID AND
       PP.ValPhoneTypeID = MSP.ValPhoneTypeID
  LEFT JOIN dbo.vValPhoneType VPT
       ON MSP.ValPhoneTypeID = VPT.ValPhoneTypeID
  LEFT JOIN dbo.vMembershipAddress MA
       ON MS.MembershipID = MA.MembershipID
  LEFT JOIN dbo.vValState VS
       ON MA.ValStateID = VS.ValStateID
  LEFT JOIN dbo.vValCountry VC
       ON MA.ValCountryID = VC.ValCountryID
  LEFT JOIN dbo.vValTerminationReason VTR
       ON VTR.ValTerminationReasonID = MS.ValTerminationReasonID 
 WHERE M.ActiveFlag = 1 AND
       VMS.Description IN ('Active', 'Late Activation', 'Non-Paid', 'Non-Paid, Late Activation', 'Pending Termination', 'Suspended') AND
       M.JoinDate BETWEEN @StartDate AND @EndDate AND
       C.DisplayUIFlag = 1 AND
       MST.ShortTermMembershipFlag = 0 and
       VMT.Description IN (SELECT MemberType FROM #MemberTypes) AND
       C.ClubID IN (SELECT ClubID FROM #Clubs)


-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity


DROP TABLE #Clubs
DROP TABLE #MemberTypes
DROP TABLE #tmpList
END










