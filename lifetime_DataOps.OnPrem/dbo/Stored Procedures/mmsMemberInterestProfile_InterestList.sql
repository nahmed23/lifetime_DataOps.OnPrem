



--
-- Returns a member interest profile
--
-- Parameters: ClubList ProfileSectionList and ProfileItemList can be either a | separated list or 'All'
--     Zipstart and Zipend can be a valid range of zipcodes or 'All'
--     Gender can be Male Female or Both
--

CREATE  PROC dbo.mmsMemberInterestProfile_InterestList (
  @ClubList VARCHAR(1000),
  @ProfileSectionList VARCHAR(1000),
  @ProfileItemList VARCHAR(1000),
  @ZIPStart VARCHAR(9),
  @ZIPEnd VARCHAR(9),
  @Gender VARCHAR(10)
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
  CREATE TABLE #Clubs (ClubName VARCHAR(50))
  CREATE TABLE #ProfileSections (Category VARCHAR(50))
  CREATE TABLE #ProfileItems (ItemDescription VARCHAR(50))
  
  IF @ClubList <> 'All'
  BEGIN
     EXEC procParseStringList @ClubList
     INSERT INTO #Clubs (ClubName) SELECT StringField FROM #tmpList
     TRUNCATE TABLE #tmpList
  END
  ELSE
  BEGIN
    INSERT INTO #Clubs (ClubName) VALUES ('All')
  END
  
  IF @ProfileSectionList <> 'All'
  BEGIN
     EXEC procParseStringList @ProfileSectionList
     INSERT INTO #ProfileSections (Category) SELECT StringField FROM #tmpList
     TRUNCATE TABLE #tmpList
  END
  ELSE
  BEGIN
    INSERT INTO #ProfileSections (Category) VALUES ('All')
  END
  
  IF @ProfileItemList <> 'All'
  BEGIN
     EXEC procParseStringList @ProfileItemList
     INSERT INTO #ProfileItems (ItemDescription) SELECT StringField FROM #tmpList
     TRUNCATE TABLE #tmpList
  END
  ELSE
  BEGIN
    INSERT INTO #ProfileItems (ItemDescription) VALUES ('All')
  END
  
  DECLARE @GenderLimit VARCHAR(1)
  
  SET @GenderLimit = 
    CASE @Gender
      WHEN 'Male' THEN 'M'
      WHEN 'Female' THEN 'F'
      WHEN 'Both' THEN 'B'
    END

  SELECT C.ClubName, CID.Category, CID.Item,
         M.MIPUpdatedDateTime ProfileDate_Mipupdateddatetime, 
         M.Gender, M.EmailAddress,
         P.Description MembershipTypeDescription, M.FirstName, M.LastName,
         M.DOB, M.MemberID, VR.Description RegionDescription,
         COM.Comment, CID.SubCategory, CID.AllowCommentFlag,
         CID.ActiveFlag ItemActiveflag, MSA.Zip MembershipZipcode, 
         MSP.AreaCode,
         MSP.Number PhoneNumber
    FROM dbo.vMember M
    JOIN dbo.vMembershipAddress MSA
         ON M.MembershipID = MSA.MembershipID
    JOIN dbo.vMembership MS
         ON MS.MembershipID = M.MembershipID
    JOIN dbo.vCLUB C
         ON C.ClubID = MS.ClubID
    JOIN #Clubs tC
         ON C.ClubName = tC.ClubName OR
         tC.ClubName = 'All'
    JOIN dbo.vValMembershipStatus VMS
         ON MS.ValMembershipStatusID = VMS.ValMembershipStatusID
    JOIN dbo.vMembershipType MST
         ON MS.MembershipTypeID = MST.MembershipTypeID
    JOIN dbo.vProduct P
         ON MST.ProductID = P.ProductID
    JOIN dbo.vValRegion VR
         ON C.ValRegionID = VR.ValRegionID
    JOIN dbo.vMIPMemberCategoryItem MCI
         ON M.MemberID = MCI.MemberID
    JOIN dbo.vMIPCategoryItemDescription CID
         ON MCI.MIPCategoryItemID = CID.MIPCategoryItemID
    JOIN #ProfileSections PS
         ON CID.Category = PS.Category OR
         PS.Category = 'All'
    JOIN #ProfileItems PI
         ON CID.Item = PI.ItemDescription OR
         PI.ItemDescription = 'All'
    LEFT JOIN dbo.vPrimaryPhone PP
         ON MS.MembershipID = PP.MembershipID
    LEFT JOIN dbo.vMembershipPhone MSP
         ON PP.MembershipID = MSP.MembershipID AND PP.ValPhoneTypeID = MSP.ValPhoneTypeID 
    LEFT JOIN dbo.vMIPMemberCategoryItemComment COM
         ON MCI.MIPMemberCategoryItemID = COM.MIPMemberCategoryItemID 
   WHERE VMS.Description = 'Active' AND
         M.ActiveFlag = 1 AND
         CID.ActiveFlag = 1 AND
         MSA.Zip BETWEEN @ZipStart AND @ZipEnd AND
         (M.Gender = @GenderLimit OR
         @GenderLimit = 'B')

  DROP TABLE #tmpList
  DROP TABLE #Clubs
  DROP TABLE #ProfileSections
  DROP TABLE #ProfileItems

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END




