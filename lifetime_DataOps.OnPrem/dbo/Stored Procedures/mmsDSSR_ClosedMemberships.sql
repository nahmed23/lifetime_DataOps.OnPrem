








--
--THIS PROCEDURE RETUNRS THE DETAILS OF MEMBERSHIP SOLD
--FOR MONTH TO DAY TILL YESTERDAY FOR A GIVEN CLUB(S).
--
-- one parameter is a list of clubname with a | delimiter
--   if clublist is 'All' it includes all clubs
--

CREATE                 PROCEDURE dbo.mmsDSSR_ClosedMemberships (
  @ClubList VARCHAR(1000)
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

  DECLARE @Yesterday DATETIME
  DECLARE @FirstOfMonth DATETIME
  
  CREATE TABLE #tmpList (StringField VARCHAR(50))
  
-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

  -- Parse the ClubIDs into a temp table
  EXEC procParseStringList @ClubList
  CREATE TABLE #Clubs (ClubName VARCHAR(50))
  INSERT INTO #Clubs (ClubName) SELECT StringField FROM #tmpList

  SET @Yesterday  =  DATEADD(dd, -1, CONVERT(DATETIME, CONVERT(VARCHAR, GETDATE(), 102), 102))
  SET @FirstOfMonth  =  CONVERT(DATETIME, SUBSTRING(CONVERT(VARCHAR,@yesterday,112),1,6) + '01', 112)

  SELECT DISTINCT MembershipClubID ClubID, MembershipClubName ClubName, MemberID, PrimaryMemberFirstName,
         PrimaryMemberLastName,JoinDate, CreatedDateTime,MembershipTypeDescription,
         AdvisorFirstName,AdvisorLastName,MembershipSizeDescription, @Yesterday ReportDate,CompanyID,
         CorporateAccountRepInitials,CorpAccountRepType,CorporateCode,AdvisorEmployeeID,Join_Today_Flag,
         Email_OnFile_Flag,ProductDescription,ItemAmount, CP.Price AS MembershipDuesPrice,
         VR.Description AS MMS_Region
    FROM vDSSRSummary DS
    JOIN #Clubs tC ON DS.mEMBeRSHIPClubName = tC.ClubName
                   OR tC.ClubName = 'All'
    JOIN vProduct P
         ON DS.MembershipTypeDescription = P.Description
    JOIN vClubProduct CP
         ON CP.ProductID = P.ProductID
         AND CP.ClubID = DS.MembershipClubID
    JOIN vCLUB C
         ON DS.MembershipClubID = C.ClubID
    JOIN vValRegion VR
         ON C.ValRegionID = VR.ValRegionID
   WHERE DS.JoinDate >= @FirstOfMonth 
         AND
         DS.JoinDate <= @Yesterday 
         AND
         DS.MembershipTypeDescription NOT LIKE '%Employee%' AND 
         DS.MembershipTypeDescription NOT LIKE '%Short%' AND
         DS.MembershipTypeDescription NOT LIKE '%Trade%' AND
         DS.ProductID = 88 --- Limited to just summary table membership records with an Initiation Fee transaction
   ORDER BY DS.MembershipClubName

  DROP TABLE #tmpList
  DROP TABLE #Clubs

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END








