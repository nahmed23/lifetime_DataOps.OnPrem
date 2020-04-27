


--
-- returns info for members in the medica program
--
-- Parameters: a enrollment date range
--

CREATE  PROC dbo.mmsMedicaEnrollmentAnalysis_NewTransferEligible (
  @StartDate SMALLDATETIME,
  @EndDate SMALLDATETIME,
  @ClubList VARCHAR(1000),
  @MemberIDList VARCHAR(1000),
  @UseDatesFlag INT
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
  CREATE TABLE #Members (MemberID INT)
  
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
  
  IF @MemberIDList <> 'All'
  BEGIN
     EXEC procParseStringList @MemberIDList
     INSERT INTO #Members (MemberID) SELECT StringField FROM #tmpList
     TRUNCATE TABLE #tmpList
  END
  ELSE
  BEGIN
    INSERT INTO #Members (MemberID) VALUES (-100)
  END
  
  SELECT C.ClubName, 
         MS.MembershipID, 
         M.MemberID,
         M.FirstName, 
         M.LastName, 
         M.JoinDate,
         M.CWProgramEnrolledFlag, 
         M.CWEnrollmentDate, 
         M.CWMedicaNumber,
         CMP.CorporateCode, 
         CMP.CompanyName, 
         VMS.Description MembershipStatusDescription,
         DATEDIFF(day, M.JoinDate, M.CWEnrollmentDate) DaysBetweenJoinAndMedicaDate,
         VMT.Description MemberTypeDiscription, 
         MS.ExpirationDate,
         CASE 
           WHEN DATEDIFF(day, M.JoinDate, M.CWEnrollmentDate) <= 7 then 'New'
           ELSE 'Transfer'
         END TransferOrNewMember,
         SUBSTRING(M.CWMedicaNumber, 1, 5) MedicaGroupID,
         MC.MedicaCompanyName,
         MC.StartDate,
         MC.EndDate,
         MC.ValMedicaProgramID
    FROM dbo.vCLUB C
    JOIN #Clubs tC
         ON tC.ClubName = C.ClubName OR tC.ClubName = 'All'
    JOIN dbo.vMembership MS
         ON C.ClubID = MS.ClubID
    JOIN dbo.vMember M
         ON MS.MembershipID = M.MembershipID
    JOIN #Members tM
         ON tM.MemberID = M.MemberID OR tM.MemberID = -100
    JOIN dbo.vValMembershipStatus VMS
         ON VMS.ValMembershipStatusID = MS.ValMembershipStatusID
    JOIN dbo.vValMemberType VMT
         ON M.ValMemberTypeID = VMT.ValMemberTypeID
    LEFT JOIN dbo.vCompany CMP
         ON MS.CompanyID = CMP.CompanyID
    LEFT JOIN dbo.vMedicaCompany MC
         ON SUBSTRING(M.CWMedicaNumber, 1, 5) = MC.MedicaCompanyCode
   WHERE M.CWMedicaNumber > '0' AND
         (M.CWEnrollmentDate BETWEEN @StartDate AND @EndDate OR
         @UseDatesFlag = 0)

  DROP TABLE #Clubs
  DROP TABLE #Members
  DROP TABLE #tmpList

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity
  
END



