


--
-- finds employer listings for non corporate memberships
-- parameters: startdate, endate, employer range, selected clubs, alldatesflag
-- all dates flag is to accommodate someone wanting to include all dates
--

CREATE   PROCEDURE dbo.mmsEmployerReview (
  @ClubIDList VARCHAR(2000),
  @StartDate SMALLDATETIME,
  @EndDate SMALLDATETIME,
  @StartEmp VARCHAR(1000),
  @EndEmp VARCHAR(1000),
  @AllDatesFlag INT
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
  
  -- Parse the ClubIDs into a temp table
  EXEC procParseStringList @ClubIDList
  CREATE TABLE #Clubs (ClubID VARCHAR(15))
  INSERT INTO #Clubs (ClubID) SELECT StringField FROM #tmpList

   SELECT C.ClubName, VMT.Description AS MemberTypeDescription, M.MemberID,
          M.FirstName, M.LastName, MS.CompanyID,
          ER.EmployerID, ER.EmployerName, ERA.AddressLine1,
          ERA.AddressLine2, ERA.City, ERA.Zip,
          M.JoinDate AS MemberJoinDate, VR.Description AS RegionDescription, 
          E.FirstName AS AdvisorFirstName, E.LastName AS AdvisorLastName, 
          M.JoinDate, VS.Abbreviation AS StateAbbreviation,
          VC.Abbreviation AS CountryAbbreviation
     FROM dbo.vClub C 
     JOIN #Clubs CI
          ON C.ClubID = CI.ClubID
--          ON C.ClubName = CI.ClubName
     JOIN dbo.vMembership MS
          ON MS.ClubID = C.ClubID
     JOIN dbo.vMember M 
          ON M.MembershipID = MS.MembershipID
     JOIN dbo.vValMembershipStatus VMSS
          ON MS.ValMembershipStatusID = VMSS.ValMembershipStatusID
     JOIN dbo.vValMemberType VMT
          ON M.ValMemberTypeID = VMT.ValMemberTypeID
     JOIN dbo.vValRegion VR
          ON C.ValRegionID = VR.ValRegionID
     JOIN dbo.vEmployee E
          ON MS.AdvisorEmployeeID = E.EmployeeID
     JOIN dbo.vEmployer ER 
          ON M.EmployerID = ER.EmployerID
     LEFT OUTER JOIN dbo.vEmployerAddress ERA
          ON ER.EmployerID = ERA.EmployerID
     LEFT OUTER JOIN dbo.vValState VS
          ON ERA.ValStateID = VS.ValStateID
     LEFT OUTER JOIN dbo.vValCountry VC
          ON ERA.ValCountryID = VC.ValCountryID
    WHERE ER.EmployerName BETWEEN @StartEmp AND @EndEmp AND
          (M.JoinDate BETWEEN @StartDate AND @EndDate OR
          @AllDatesFlag = 1) AND
          M.ActiveFlag = 1 AND
          VMSS.Description = 'Active' AND
          MS.CompanyID IS NULL

  DROP TABLE #Clubs
  DROP TABLE #tmpList

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END



