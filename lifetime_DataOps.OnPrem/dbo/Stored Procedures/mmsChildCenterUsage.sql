

--
--this procedure will return childcare usage details for a given time period.
--

CREATE PROCEDURE dbo.mmsChildCenterUsage (
  @StartDate datetime,
  @EndDate datetime,
  @ClubList VARCHAR(8000),
  @MemberID INT,
  @AllMembershipMembersFlag BIT
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
  
  -- Parse the ClubIDs into a temp table
  EXEC procParseStringList @ClubList
  CREATE TABLE #Clubs (ClubName VARCHAR(50))
  INSERT INTO #Clubs (ClubName) SELECT StringField FROM #tmpList

  IF @MemberID <> 0
  BEGIN
    IF @AllMembershipMembersFlag = 0
    BEGIN
      SELECT CM.MemberID ChildMemberid, CM.FirstName ChildFirstname, CM.LastName ChildLastname, 
             CIM.MemberID CheckinParent_MemberID, CIM.FirstName CheckinParent_Firstname, CIM.LastName CheckinParent_Lastname, 
             COM.MemberID CheckoutParent_MemberID, COM.FirstName CheckoutParent_Firstname, COM.LastName CheckoutParent_Lastname, 
             CCU.CheckInDateTime, CCU.CheckOutDateTime, CM.MembershipID, PM.MemberID PrimaryMemberID, PM.FirstName PrimaryFirstname, 
             PM.LastName PrimaryLastname, CM.DOB ChildDOB, R.Description RegionDescription, C.ClubName, GETDATE() ReportDateTime 
        FROM dbo.vChildCenterUsage CCU JOIN dbo.vMember CM ON CCU.MemberID=CM.MemberID
        JOIN dbo.vMember CIM ON CCU.CheckInMemberID=CIM.MemberID
        JOIN dbo.vMember PM ON CM.MembershipID=PM.MembershipID
        JOIN dbo.vClub C ON CCU.ClubID=C.ClubID	
        JOIN #Clubs TC ON C.ClubName=TC.ClubName
             OR TC.ClubName = 'All'
        JOIN dbo.vValRegion R ON C.ValRegionID=R.ValRegionID
        LEFT OUTER JOIN dbo.vMember COM ON CCU.CheckOutMemberID=COM.MemberID 
       WHERE CCU.CheckInDateTime >= @StartDate 
             AND CCU.CheckInDateTime <= @EndDate 
             AND PM.ValMemberTypeID=1 
             AND CM.MemberID=@MemberID 
    END
    ELSE
    BEGIN
      SELECT CM.MemberID ChildMemberid, CM.FirstName ChildFirstname, CM.LastName ChildLastname, 
	     CIM.MemberID CheckinParent_MemberID, CIM.FirstName CheckinParent_Firstname, CIM.LastName CheckinParent_Lastname, 
             COM.MemberID CheckoutParent_MemberID, COM.FirstName CheckoutParent_Firstname, COM.LastName CheckoutParent_Lastname, 
             CCU.CheckInDateTime, CCU.CheckOutDateTime, CM.MembershipID, PM.MemberID PrimaryMemberID, PM.FirstName PrimaryFirstname, 
             PM.LastName PrimaryLastname, CM.DOB ChildDOB, R.Description RegionDescription, C.ClubName, GETDATE() ReportDateTime
        FROM dbo.vChildCenterUsage CCU JOIN dbo.vMember CM ON CCU.MemberID=CM.MemberID
        JOIN dbo.vMember CIM ON CCU.CheckInMemberID=CIM.MemberID
        JOIN dbo.vMember PM ON CM.MembershipID=PM.MembershipID 
        JOIN dbo.vMember MM ON MM.MembershipID = CM.MembershipID AND MM.MemberID=@MemberID
        JOIN dbo.vClub C ON CCU.ClubID=C.ClubID
        JOIN #Clubs TC ON C.ClubName=TC.ClubName
             OR TC.ClubName = 'All'
        JOIN dbo.vValRegion R ON C.ValRegionID=R.ValRegionID
        LEFT OUTER JOIN dbo.vMember COM ON CCU.CheckOutMemberID=COM.MemberID 
       WHERE CCU.CheckInDateTime >= @StartDate 
             AND CCU.CheckInDateTime <= @EndDate 
             AND PM.ValMemberTypeID=1
    END
  END
  ELSE
  BEGIN
    SELECT CM.MemberID ChildMemberid, CM.FirstName ChildFirstname, CM.LastName ChildLastname, 
           CIM.MemberID CheckinParent_MemberID, CIM.FirstName CheckinParent_Firstname, CIM.LastName CheckinParent_Lastname, 
           COM.MemberID CheckoutParent_MemberID, COM.FirstName CheckoutParent_Firstname, COM.LastName CheckoutParent_Lastname, 
           CCU.CheckInDateTime, CCU.CheckOutDateTime, CM.MembershipID, PM.MemberID PrimaryMemberID, PM.FirstName PrimaryFirstname, 
           PM.LastName PrimaryLastname,CM.DOB ChildDOB, R.Description RegionDescription, C.ClubName, GETDATE() ReportDateTime
      FROM dbo.vChildCenterUsage CCU 
      JOIN dbo.vMember CM ON CCU.MemberID=CM.MemberID
      JOIN dbo.vMember CIM ON CCU.CheckInMemberID=CIM.MemberID
      JOIN dbo.vMember PM ON CM.MembershipID=PM.MembershipID
      JOIN dbo.vClub C ON CCU.ClubID=C.ClubID
      JOIN #Clubs TC ON C.ClubName=TC.ClubName
           OR TC.ClubName = 'All'
      JOIN dbo.vValRegion R ON C.ValRegionID=R.ValRegionID
      LEFT OUTER JOIN dbo.vMember COM ON CCU.CheckOutMemberID=COM.MemberID 
     WHERE CCU.CheckInDateTime >= @StartDate 
           AND CCU.CheckInDateTime <= @EndDate 
           AND PM.ValMemberTypeID=1 
  END

  DROP TABLE #tmpList
  DROP TABLE #Clubs

-- Report Logging
UPDATE HyperionReportLog
SET EndDateTime = getdate()
WHERE ReportLogID = @Identity

END



