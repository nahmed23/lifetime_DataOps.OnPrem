


--
--  THIS PROCEDURE RETURNS THE TOTAL NUMBER OF EACH TYPE OF MEMBERSHIP
--  AND THE TOTAL DUES IT SHOULD BRING IN MONTHLY
--
-- Params: A | separated CLUB ID List AND a DATE RANGE
--
-- EXEC mmsDuesAssessment '10', '6/1/04', '6/5/04'
CREATE    PROCEDURE dbo.mmsDuesAssessment (
  @ClubIDs VARCHAR(1000),
  @InputStartDate DATETIME,
  @InputEndDate DATETIME
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

  CREATE TABLE #tmpList (StringField VARCHAR(50))

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY
  
  -- Parse the ClubIDs into a temp table
  EXEC procParseIntegerList @ClubIDs
  CREATE TABLE #Clubs (ClubID INT)
  INSERT INTO #Clubs (ClubID) SELECT StringField FROM #tmpList

  SELECT C.ClubName, 
         Count(M.MembershipID) AS CountofMemberships, 
--         M.FirstName, 
--         M.LastName,
         P.Description ProductDescription,
         Sum(MT.TranAmount) AS TotalAssessment,
--         M.MemberID,
         VR.Description RegionDescription,
--         M.JoinDate,
--         MT.PostDateTime,
         P.DepartmentID,
	 MT.ReasonCodeID,
	 @InputStartDate
    FROM vMMSTran MT
         JOIN vMember M ON MT.MemberID = M.MemberID
         JOIN vTranItem TI ON MT.MMSTranID = TI.MMSTranID
         JOIN vProduct P ON TI.ProductID = P.ProductID
         JOIN vClub C ON MT.ClubID = C.ClubID
         JOIN #Clubs CI ON C.ClubID = CI.ClubID
         JOIN vValRegion VR ON C.ValRegionID =  VR.ValRegionID
   WHERE MT.ValTranTypeID = 1 AND --- TranType 1 is a Charge Transaction
         MT.PostDateTime > @InputStartDate AND
         MT.PostDateTime < @InputEndDate AND
         M.ValMemberTypeID = 1 AND
         MT.EmployeeID = -2 AND
         P.DepartmentID IN(1,3) AND
         C.DisplayUIFlag = 1
   GROUP BY C.ClubName, P.Description, MT.ReasonCodeID, VR.Description, P.DepartmentID

  DROP TABLE #Clubs
  DROP TABLE #tmpList

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END



