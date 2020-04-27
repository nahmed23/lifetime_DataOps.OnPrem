



-- Returns a set of membershipIDs contained within the given clublist
-- with one of the given terminationreasons with the given 
-- Communication Preference.

CREATE      PROC dbo.mmsCancelationReasons_FlaggedMemberships
  @ClubList VARCHAR(8000),
  @TerminationReasonList VARCHAR(8000),
  @CommFlagPrefDescription VARCHAR(50)
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
  EXEC procParseIntegerList @ClubList
  CREATE TABLE #Clubs (ClubID VARCHAR(50))
  INSERT INTO #Clubs (ClubID) SELECT StringField FROM #tmpList
  TRUNCATE TABLE #tmpList

  -- Parse the TermReasons into a temp table
  EXEC procParseIntegerList @TerminationReasonList
  CREATE TABLE #TermReasons (ReasonID VARCHAR(50))
  INSERT INTO #TermReasons (ReasonID) SELECT StringField FROM #tmpList
  TRUNCATE TABLE #tmpList

  SELECT MS.MembershipID, VCP.Description FlagDescription, MCP.ValCommunicationPreferenceID 
    FROM dbo.vMembership MS
    JOIN dbo.vMembershipCommunicationPreference MCP
         ON MS.MembershipID = MCP.MembershipID
    JOIN dbo.vValCommunicationPreference VCP
         ON MCP.ValCommunicationPreferenceID = VCP.ValCommunicationPreferenceID
    JOIN dbo.vClub C
         ON MS.ClubID = C.ClubID
    JOIN dbo.vValTerminationReason VTR
         ON MS.ValTerminationReasonID = VTR.ValTerminationReasonID
    JOIN #Clubs tmpC
         ON C.ClubID = tmpC.ClubID
    JOIN #TermReasons TR
         ON VTR.ValTerminationReasonID = TR.ReasonID
   WHERE MCP.ActiveFlag = 1 AND
         VCP.Description = @CommFlagPrefDescription

  DROP TABLE #tmpList
  DROP TABLE #Clubs
  DROP TABLE #TermReasons

-- Report Logging
UPDATE HyperionReportLog
SET EndDateTime = getdate()
WHERE ReportLogID = @Identity

END




