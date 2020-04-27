

--
-- returns Member status info for the Memberstatussummary Brio bqy
--
-- Parameters: A | separated list of Club IDs
--

CREATE     PROC dbo.mmsMemberstatussummary_MemberCounts (
  @ClubIDList VARCHAR(1000)
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON
CREATE TABLE #tmpList (StringField VARCHAR(50))
CREATE TABLE #Clubs (ClubID VARCHAR(50))

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

--INSERT INTO #Clubs EXEC procParseStringList @ClubList
   EXEC procParseStringList @ClubIDList
   INSERT INTO #Clubs (ClubID) SELECT StringField FROM #tmpList


SELECT C.ClubName, P.Description AS ProductDescription, Count (M.MemberID) AS MemberID,
       M.ValMemberTypeID, P.ProductID, C.ClubID
  FROM dbo.vMember M
  JOIN dbo.vMembership MS
       ON M.MembershipID = MS.MembershipID
  JOIN dbo.vClub C
       ON MS.ClubID = C.ClubID
  JOIN #Clubs CS
       ON (C.ClubID = CS.ClubID or CS.ClubID = 'ALL')
  JOIN dbo.vValMembershipStatus VMS
       ON VMS.ValMembershipStatusID = MS.ValMembershipStatusID
  JOIN dbo.vMembershipType MST
       ON MS.MembershipTypeID = MST.MembershipTypeID
  JOIN dbo.vProduct P 
       ON MST.ProductID = P.ProductID
 WHERE VMS.Description IN ('Active', 'Non-Paid', 'Pending Termination') AND
       M.ActiveFlag = 1
GROUP BY C.ClubName, P.Description, M.ValMemberTypeID, P.ProductID, C.ClubID

DROP TABLE #Clubs
DROP TABLE #tmpList

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END



