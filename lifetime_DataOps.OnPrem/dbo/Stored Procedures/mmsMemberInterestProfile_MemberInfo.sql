



--
-- Returns a member interest, member information list
--
-- Parameters: ClubList can be either a | separated list or 'All'
--     Zipstart and Zipend can be a valid range of zipcodes or 'All'
--     Gender can be Male Female or Both
--
-- EXEC dbo.mmsMemberInterestProfile_MemberInfo 'All', '00000', '99999', 'Both'
--
CREATE           PROC dbo.mmsMemberInterestProfile_MemberInfo (
  @ClubList VARCHAR(1000),
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
  CREATE TABLE #Clubs (ClubID INT)
  
--  IF @ClubList <> 'All'
  BEGIN
     EXEC procParseStringList @ClubList
     INSERT INTO #Clubs (ClubID) SELECT StringField FROM #tmpList
     TRUNCATE TABLE #tmpList
  END
--  ELSE
--  BEGIN
--    INSERT INTO #Clubs (ClubID) VALUES ('All')
--  END
  
  DECLARE @GenderLimit VARCHAR(1)
  
  SET @GenderLimit = 
    CASE @Gender
      WHEN 'Male' THEN 'M'
      WHEN 'Female' THEN 'F'
      WHEN 'Both' THEN 'B'
    END

  SELECT C.ClubName, M.Gender, M.EmailAddress,
         P.Description MembershipTypeDescription, M.FirstName, M.LastName,
         M.DOB, M.MemberID, M.MembershipID, VR.Description RegionDescription,
	 MSA.Zip MembershipZipcode, 
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
         ON C.ClubID = tC.ClubID --OR
--         tC.ClubID = 'All'
    JOIN dbo.vValMembershipStatus VMS
         ON MS.ValMembershipStatusID = VMS.ValMembershipStatusID
    JOIN dbo.vMembershipType MST
         ON MS.MembershipTypeID = MST.MembershipTypeID
    JOIN dbo.vProduct P
         ON MST.ProductID = P.ProductID
    JOIN dbo.vValRegion VR
         ON C.ValRegionID = VR.ValRegionID
    LEFT JOIN dbo.vPrimaryPhone PP
         ON MS.MembershipID = PP.MembershipID
    LEFT JOIN dbo.vMembershipPhone MSP
         ON PP.MembershipID = MSP.MembershipID AND PP.ValPhoneTypeID = MSP.ValPhoneTypeID 
   WHERE VMS.Description = 'Active' AND
         M.ActiveFlag = 1 AND
         MSA.Zip BETWEEN @ZipStart AND @ZipEnd AND
         (M.Gender = @GenderLimit OR
         @GenderLimit = 'B')
 

  DROP TABLE #tmpList
  DROP TABLE #Clubs

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END




