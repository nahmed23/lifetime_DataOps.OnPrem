



















--
-- Returns a recordset specific to the Corpprodsum Brio Document for
-- the qProductionSummary Query section
-- 
-- Parameters required: Date range for the members join date
--    and a | separated list of AccountRepInitials
--

CREATE       PROC dbo.mmsCorpprodsum_ProductionSummary_old(
  @StartDate SMALLDATETIME,
  @EndDate SMALLDATETIME,
  @AccountRepInitialsList VARCHAR(1000)
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
--  EXEC procParseStringList @AccountRepInitialsList
  insert into #tmpList (StringField) select distinct accountrepinitials from dbo.vCompany

  CREATE TABLE #ARList (AccountRepInitials VARCHAR(5))
  INSERT INTO #ARList (AccountRepInitials) SELECT StringField FROM #tmpList

  SELECT VR.Description RegionDescription, COMP.CorporateCode, COMP.CompanyID, 
         COMP.CompanyName Company, COMP.AccountRepInitials [Account Rep], C.ClubName Club, 
         ISNULL(M.FirstName, '') + ISNULL(' ' + M.LastName, '') [Member Name], MS.CancellationRequestDate, 
         M.MemberID [Member Id], M.JoinDate, P.Description MembershipTypeDescription, 
         TI.ItemAmount, MS.CreatedDateTime, MMST.PostDateTime 
    FROM dbo.vClub C
    JOIN dbo.vMembership MS
         ON MS.ClubID=C.ClubID
    JOIN dbo.vMember M
         ON M.MembershipID=MS.MembershipID
    JOIN dbo.vValRegion VR
         ON VR.ValRegionID=C.ValRegionID
    JOIN vValMemberType VMT
         ON VMT.ValMemberTypeID=M.ValMemberTypeID
    JOIN dbo.vCompany COMP
         ON MS.CompanyID=COMP.CompanyID
    JOIN #ARList AR 
         ON COMP.AccountRepInitials = AR.AccountRepInitials
    JOIN dbo.vMembershipType MST
         ON MS.MembershipTypeID=MST.MembershipTypeID
    JOIN dbo.vProduct P
         ON P.ProductID=MST.ProductID
    JOIN dbo.vMMSTran MMST
         ON MS.MembershipID=MMST.MembershipID
    JOIN dbo.vTranItem TI
         ON MMST.MMSTranID=TI.MMSTranID
    JOIN dbo.vProduct P2 
         ON TI.ProductID=P2.ProductID
   WHERE M.JoinDate BETWEEN @StartDate AND @EndDate AND 
         P2.Description='Initiation Fee' AND 
         VMT.Description='Primary' AND 
         MMST.TranVoidedID IS NULL 
 	 --AND TI.InsertedDateTime >= @StartDate

  DROP TABLE #ARList
  DROP TABLE #tmpList

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END




















